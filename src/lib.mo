import Result "mo:new-base/Result";
import Time "mo:new-base/Time";
import Nat64 "mo:new-base/Nat64";
import Nat8 "mo:new-base/Nat8";
import Text "mo:new-base/Text";
import Runtime "mo:new-base/Runtime";
import Nat "mo:new-base/Nat";
import BaseX "mo:base-x-encoder";
import NatX "mo:xtended-numbers/NatX";
import Buffer "mo:base/Buffer";

module {

    /// Represents a TID (Timestamp Identifier) - a compact, sortable identifier
    /// based on a timestamp with microsecond precision and a clock identifier.
    ///
    /// ```motoko
    /// let tid : TID = { timestamp = 1640995200000000; clockId = 42; };
    /// ```
    public type TID = {
        timestamp : Nat; // Microseconds since UNIX epoch (max 53 bits)
        clockId : Nat; // Clock identifier (max 10 bits: 0-1023)
    };

    private let TID_LENGTH = 13;
    private let MAX_TIMESTAMP : Nat = 9007199254740991; // 2^53 - 1 for JavaScript compatibility
    private let MAX_CLOCK_ID : Nat = 1023; // 10 bits max (2^10 - 1)
    private let HIGH_BIT_MASK : Nat64 = 9223372036854775808; // 2^63

    /// Converts a TID to its base32-sortable text representation.
    ///
    /// ```motoko
    /// let tid : TID = { timestamp = 1640995200000000; clockId = 42; };
    /// let text = TID.toText(tid);
    /// // Returns: 13-character base32-sortable string
    /// ```
    public func toText(tid : TID) : Text {
        // Validate inputs
        if (tid.timestamp > MAX_TIMESTAMP) {
            Runtime.trap("Timestamp too large: " # Nat.toText(tid.timestamp) # " > " # Nat.toText(MAX_TIMESTAMP));
        };
        if (tid.clockId > MAX_CLOCK_ID) {
            Runtime.trap("Clock ID too large: " # Nat.toText(tid.clockId) # " > " # Nat.toText(MAX_CLOCK_ID));
        };

        let nat64Value = toNat64(tid);
        let bytes = Buffer.Buffer<Nat8>(8);
        NatX.encodeNat64(bytes, nat64Value, #msb);
        BaseX.toBase32(bytes.vals(), #atprotoSortable);
    };

    /// Parses a base32-sortable text string into a TID.
    ///
    /// ```motoko
    /// let result = TID.fromText("3jzfcijpj2z2a");
    /// switch (result) {
    ///   case (#ok(tid)) { /* Successfully parsed TID */ };
    ///   case (#err(error)) { /* Handle parsing error */ };
    /// };
    /// ```
    public func fromText(text : Text) : Result.Result<TID, Text> {
        // Validate length
        if (text.size() != TID_LENGTH) {
            return #err("Invalid TID length: expected " # Nat.toText(TID_LENGTH) # " characters, got " # Nat.toText(text.size()));
        };

        // Decode base32-sortable to bytes
        let bytes = switch (BaseX.fromBase32(text, #atprotoSortable)) {
            case (#ok(blob)) blob;
            case (#err(e)) return #err("Failed to decode base32-sortable: " # e);
        };

        // Should be exactly 8 bytes for 64-bit value
        if (bytes.size() != 8) {
            return #err("Invalid byte length: expected 8 bytes, got " # Nat.toText(bytes.size()));
        };

        let nat64Value = switch (NatX.decodeNat64(bytes.vals(), #msb)) {
            case (?value) value;
            case (null) return #err("Failed to convert bytes to Nat64");
        };

        // Check that top bit is 0 (ensures valid TID range)
        if (nat64Value >= HIGH_BIT_MASK) {
            return #err("Invalid TID: top bit must be 0");
        };

        fromNat64(nat64Value);
    };

    /// Creates a TID from the current time with a random clock identifier.
    ///
    /// ```motoko
    /// let clockId = Nat32.toNat(Nat32.random() % 1024); // Random clock ID in range 0-1023
    /// let tid = TID.now(clockId);
    /// // Returns a TID with current timestamp and random clock ID
    /// ```
    public func now(clockId : Nat) : TID {
        let timeNanos = Nat.fromInt(Time.now());
        {
            timestamp = timeNanos / 1000; // Convert nanoseconds to microseconds
            clockId = clockId;
        };
    };

    /// Converts a TID to its 64-bit integer representation.
    ///
    /// ```motoko
    /// let tid : TID = { timestamp = 1640995200000000; clockId = 42; };
    /// let value = TID.toNat64(tid);
    /// // Returns: 64-bit integer with packed timestamp and clock ID
    /// ```
    public func toNat64(tid : TID) : Nat64 {
        // Validate inputs
        if (tid.timestamp > MAX_TIMESTAMP) {
            Runtime.trap("Timestamp too large: " # Nat.toText(tid.timestamp) # " > " # Nat.toText(MAX_TIMESTAMP));
        };
        if (tid.clockId > MAX_CLOCK_ID) {
            Runtime.trap("Clock ID too large: " # Nat.toText(tid.clockId) # " > " # Nat.toText(MAX_CLOCK_ID));
        };

        // Pack: 0 (top bit) + 53 bits timestamp + 10 bits clock ID
        let timestampPart = Nat64.fromNat(tid.timestamp) << 10;
        let clockIdPart = Nat64.fromNat(tid.clockId);
        timestampPart | clockIdPart;
    };

    /// Converts a 64-bit integer to a TID.
    ///
    /// ```motoko
    /// let value : Nat64 = 1640995200000000 << 10 | 42;
    /// let result = TID.fromNat64(value);
    /// switch (result) {
    ///   case (#ok(tid)) { /* Successfully converted */ };
    ///   case (#err(error)) { /* Invalid value */ };
    /// };
    /// ```
    public func fromNat64(value : Nat64) : Result.Result<TID, Text> {
        // Check that top bit is 0
        if (value >= HIGH_BIT_MASK) {
            return #err("Invalid TID value: top bit must be 0");
        };

        let timestamp = Nat64.toNat(value >> 10); // Extract top 54 bits
        let clockId = Nat64.toNat(value & 1023); // Extract bottom 10 bits

        // Additional validation (should not be necessary but good to check)
        if (timestamp > MAX_TIMESTAMP) {
            return #err("Extracted timestamp too large: " # Nat.toText(timestamp));
        };
        if (clockId > MAX_CLOCK_ID) {
            return #err("Extracted clock ID too large: " # Nat.toText(clockId));
        };

        #ok({
            timestamp = timestamp;
            clockId = clockId;
        });
    };

    /// Compares two TIDs for sorting. Returns negative for tid1 < tid2,
    /// zero for equal, positive for tid1 > tid2.
    ///
    /// ```motoko
    /// let tid1 : TID = { timestamp = 1000; clockId = 1; };
    /// let tid2 : TID = { timestamp = 2000; clockId = 2; };
    /// let comparison = TID.compare(tid1, tid2);
    /// // Returns: negative value (tid1 < tid2)
    /// ```
    public func compare(tid1 : TID, tid2 : TID) : Int8 {
        // First compare by timestamp
        if (tid1.timestamp < tid2.timestamp) return -1;
        if (tid1.timestamp > tid2.timestamp) return 1;

        // If timestamps equal, compare by clock ID
        if (tid1.clockId < tid2.clockId) return -1;
        if (tid1.clockId > tid2.clockId) return 1;

        return 0; // Equal
    };

    /// Checks if two TIDs are equal.
    ///
    /// ```motoko
    /// let tid1 : TID = { timestamp = 12345; clockId = 42; };
    /// let tid2 : TID = { timestamp = 12345; clockId = 42; };
    /// let isEqual = TID.equal(tid1, tid2);
    /// // Returns: true
    /// ```
    public func equal(tid1 : TID, tid2 : TID) : Bool {
        tid1.timestamp == tid2.timestamp and tid1.clockId == tid2.clockId;
    };

};
