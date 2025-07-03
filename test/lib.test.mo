import TID "../src";
import Debug "mo:base/Debug";
import Text "mo:new-base/Text";
import Nat "mo:new-base/Nat";
import { test } "mo:test";

func testTid(
  expectedText : Text,
  expectedTid : TID.TID,
) {
  testTidToText(expectedTid, expectedText);
  testTidFromText(expectedText, expectedTid);
  testTidRoundtrip(expectedText);
};

func testTidToText(
  tid : TID.TID,
  expectedText : Text,
) {
  let actualText = TID.toText(tid);

  if (actualText != expectedText) {
    Debug.trap(
      "Text encoding mismatch for TID" #
      "\nExpected: " # debug_show (expectedText) #
      "\nActual:   " # debug_show (actualText)
    );
  };
};

func testTidFromText(
  text : Text,
  expectedTid : TID.TID,
) {
  let actualTid = switch (TID.fromText(text)) {
    case (#ok(tid)) tid;
    case (#err(e)) Debug.trap("fromText failed for '" # text # "': " # debug_show (e));
  };

  if (not TID.equal(actualTid, expectedTid)) {
    Debug.trap(
      "Parsing mismatch for '" # text # "'" #
      "\nExpected: " # debug_show (expectedTid) #
      "\nActual:   " # debug_show (actualTid)
    );
  };
};

func testTidRoundtrip(originalText : Text) {
  let parsed = switch (TID.fromText(originalText)) {
    case (#ok(tid)) tid;
    case (#err(e)) Debug.trap("Round-trip parse failed for '" # originalText # "': " # debug_show (e));
  };

  let regenerated = TID.toText(parsed);

  if (regenerated != originalText) {
    Debug.trap(
      "Round-trip mismatch for '" # originalText # "'" #
      "\nOriginal:    " # debug_show (originalText) #
      "\nRegenerated: " # debug_show (regenerated)
    );
  };
};

func testTidError(invalidText : Text) {
  switch (TID.fromText(invalidText)) {
    case (#ok(tid)) Debug.trap("Expected error for '" # invalidText # "' but got: " # debug_show (tid));
    case (#err(_)) {};
  };
};

// =============================================================================
// Basic TID Tests - Valid Examples from Specification
// =============================================================================

test(
  "TID - Minimum Value (Zero)",
  func() {
    testTid(
      "2222222222222",
      { timestamp = 0; clockId = 0 },
    );
  },
);

test(
  "TID - Zero Timestamp Components",
  func() {
    let #ok(tid) = TID.fromNat64(0) else Debug.trap("Failed to create TID from zero");

    if (tid.timestamp != 0) {
      Debug.trap("Expected zero timestamp, got: " # debug_show (tid.timestamp));
    };

    if (tid.clockId != 0) {
      Debug.trap("Expected zero clock ID, got: " # debug_show (tid.clockId));
    };
  },
);

// =============================================================================
// TID Sorting and Comparison Tests
// =============================================================================

test(
  "TID - Comparison and Sorting",
  func() {
    let tid1 = { timestamp = 1000; clockId = 1 };
    let tid2 = { timestamp = 2000; clockId = 2 };
    let tid3 = { timestamp = 2000; clockId = 3 }; // Same timestamp, different clock ID

    // Test numeric comparison
    if (TID.compare(tid1, tid2) != #less) {
      Debug.trap("Expected tid1 < tid2");
    };

    if (TID.compare(tid2, tid1) != #greater) {
      Debug.trap("Expected tid2 > tid1");
    };

    if (TID.compare(tid1, tid1) != #equal) {
      Debug.trap("Expected tid1 == tid1");
    };

    if (TID.compare(tid2, tid3) != #less) {
      Debug.trap("Expected tid2 < tid3 (same timestamp, different clock)");
    };
  },
);

test(
  "TID - String Sorting Matches Numeric Sorting",
  func() {
    let tid1 = { timestamp = 1000; clockId = 1 };
    let tid2 = { timestamp = 2000; clockId = 2 };
    let tid3 = { timestamp = 2000; clockId = 3 };

    let text1 = TID.toText(tid1);
    let text2 = TID.toText(tid2);
    let text3 = TID.toText(tid3);

    // Lexicographic string comparison should match numeric comparison
    if (not (text1 < text2)) {
      Debug.trap("String sorting failed: " # text1 # " should be < " # text2);
    };

    if (not (text2 < text3)) {
      Debug.trap("String sorting failed: " # text2 # " should be < " # text3);
    };
  },
);

test(
  "TID - Equality Test",
  func() {
    let tid1 = { timestamp = 12345; clockId = 42 };
    let tid2 = { timestamp = 12345; clockId = 42 };
    let tid3 = { timestamp = 54321; clockId = 43 };

    if (not TID.equal(tid1, tid2)) {
      Debug.trap("Expected equal TIDs to be equal");
    };

    if (TID.equal(tid1, tid3)) {
      Debug.trap("Expected different TIDs to not be equal");
    };
  },
);

// =============================================================================
// Round-trip Tests
// =============================================================================

test(
  "Round-trip: Specification Examples",
  func() {
    testTidRoundtrip("3jzfcijpj2z2a");
    testTidRoundtrip("7777777777776");
    testTidRoundtrip("3zzzzzzzzzzzy");
    testTidRoundtrip("2222222222222");
  },
);

test(
  "Round-trip: Various TID Values",
  func() {
    let testValues = [0, 1, 1023, 1024, 1000000];

    for (value in testValues.vals()) {
      let tid : TID.TID = {
        timestamp = value;
        clockId = value % 1024;
      };
      let text = TID.toText(tid);

      switch (TID.fromText(text)) {
        case (#ok(parsedTid)) {
          if (not TID.equal(tid, parsedTid)) {
            Debug.trap("Round-trip failed for value " # debug_show (value));
          };
        };
        case (#err(e)) {
          Debug.trap("Round-trip parsing failed for value " # debug_show (value) # ": " # e);
        };
      };
    };
  },
);

// =============================================================================
// Error Cases - Invalid TID Formats from Specification
// =============================================================================

test(
  "Error Cases: Invalid Characters",
  func() {
    testTidError("3jzfcijpj2z21"); // Contains '1'
    testTidError("0000000000000"); // Contains '0'
  },
);

test(
  "Error Cases: Case Sensitivity",
  func() {
    testTidError("3JZFCIJPJ2Z2A"); // Uppercase not allowed
  },
);

test(
  "Error Cases: Invalid Length",
  func() {
    testTidError("3jzfcijpj2z2aa"); // Too long (14 chars)
    testTidError("3jzfcijpj2z2"); // Too short (12 chars)
    testTidError("222"); // Too short (3 chars)
    testTidError(""); // Empty string
  },
);

test(
  "Error Cases: Legacy Dash Syntax Not Supported",
  func() {
    testTidError("3jzf-cij-pj2z-2a"); // Hyphens not allowed
  },
);

test(
  "Error Cases: High Bit Set",
  func() {
    testTidError("zzzzzzzzzzzzz"); // First char 'z' would set high bit
    testTidError("kjzfcijpj2z2a"); // First char 'k' would set high bit
  },
);

test(
  "Error Cases: Invalid First Character",
  func() {
    // First character must be 234567abcdefghij (values 0-15)
    testTidError("xjzfcijpj2z2a"); // 'x' maps to value > 15
    testTidError("yjzfcijpj2z2a"); // 'y' maps to value > 15
    testTidError("zjzfcijpj2z2a"); // 'z' maps to value > 15
  },
);

// =============================================================================
// TID Generator Tests
// =============================================================================

test(
  "TID Generator - Default Generator Creation",
  func() {
    let generator = TID.Generator();
    let tid = generator.next();

    // First TID should have clockId = 0
    if (tid.clockId != 0) {
      Debug.trap("Expected first TID from default generator to have clockId = 0, got: " # debug_show (tid.clockId));
    };

    // The timestamp should be a valid Nat value
    // In test environments, Time.now() might return 0 or small values
    // The important thing is that the generator produces a valid TID
    let text = TID.toText(tid);
    if (text.size() != 13) {
      Debug.trap("Generated TID should produce valid 13-character text representation");
    };
  },
);

test(
  "TID Generator - Clock ID Wrapping",
  func() {
    // Test wrapping behavior by starting near max value
    let generator = TID.Generator();
    for (i in Nat.range(0, 1024)) {
      // Generate TIDs until we reach 1022
      if (i != generator.next().clockId) {
        Debug.trap("Expected clockId to be " # debug_show (i) # ", got: " # debug_show (generator.next().clockId));
      };
    };

    let tid3 = generator.next(); // Should wrap to 0
    if (tid3.clockId != 0) {
      Debug.trap("Expected clockId = 0 after wrap, got: " # debug_show (tid3.clockId));
    };
  },
);

test(
  "TID Generator - Sequence Generation",
  func() {
    let generator = TID.Generator();

    // Generate a sequence of TIDs
    let tids = [
      generator.next(),
      generator.next(),
      generator.next(),
      generator.next(),
      generator.next(),
    ];

    // All should have the same timestamp
    let firstTimestamp = tids[0].timestamp;
    for (i in tids.keys()) {
      if (tids[i].timestamp != firstTimestamp) {
        Debug.trap("All TIDs from same generator should have same timestamp. TID " # debug_show (i) # " has different timestamp");
      };
    };

    // Clock IDs should be sequential: 1, 2, 3, 4, 5
    for (i in tids.keys()) {
      let expectedClockId = i;
      if (tids[i].clockId != expectedClockId) {
        Debug.trap("Expected sequential clockId " # debug_show (expectedClockId) # " for TID " # debug_show (i) # ", got: " # debug_show (tids[i].clockId));
      };
    };
  },
);

test(
  "TID Generator - Generated TIDs Are Valid",
  func() {
    let generator = TID.Generator();

    // Generate several TIDs and verify they can be serialized/deserialized
    for (i in [1, 2, 3, 4, 5].vals()) {
      let tid = generator.next();

      // Test toText conversion
      let text = TID.toText(tid);
      if (text.size() != 13) {
        Debug.trap("Generated TID text should be 13 characters, got: " # debug_show (text.size()));
      };

      // Test round-trip conversion
      let parsedResult = TID.fromText(text);
      let parsedTid = switch (parsedResult) {
        case (#ok(t)) t;
        case (#err(e)) Debug.trap("Failed to parse generated TID text '" # text # "': " # e);
      };

      if (not TID.equal(tid, parsedTid)) {
        Debug.trap("Round-trip conversion failed for generated TID");
      };
    };
  },
);

test(
  "TID Generator - Comparison and Sorting",
  func() {
    let generator = TID.Generator();

    let tid1 = generator.next(); // clockId = 0
    let tid2 = generator.next(); // clockId = 1
    let tid3 = generator.next(); // clockId = 2

    // Since they have same timestamp, ordering should be by clockId
    if (TID.compare(tid1, tid2) != #less) {
      Debug.trap("Expected tid1 < tid2 (same timestamp, sequential clock IDs)");
    };

    if (TID.compare(tid2, tid3) != #less) {
      Debug.trap("Expected tid2 < tid3 (same timestamp, sequential clock IDs)");
    };

    if (TID.compare(tid1, tid3) != #less) {
      Debug.trap("Expected tid1 < tid3 (same timestamp, sequential clock IDs)");
    };
  },
);

test(
  "TID Generator - Multiple Generators Independence",
  func() {
    let gen1 = TID.Generator();
    let gen2 = TID.Generator();

    let tid1a = gen1.next(); // clockId = 0
    let tid2a = gen2.next(); // clockId = 0
    let tid1b = gen1.next(); // clockId = 1
    let tid2b = gen2.next(); // clockId = 1

    // Verify independence - each generator maintains its own clock state
    if (tid1a.clockId != 0) {
      Debug.trap("Expected gen1 first TID to have clockId = 0, got: " # debug_show (tid1a.clockId));
    };

    if (tid2a.clockId != 0) {
      Debug.trap("Expected gen2 first TID to have clockId = 0, got: " # debug_show (tid2a.clockId));
    };

    if (tid1b.clockId != 1) {
      Debug.trap("Expected gen1 second TID to have clockId = 1, got: " # debug_show (tid1b.clockId));
    };

    if (tid2b.clockId != 1) {
      Debug.trap("Expected gen2 second TID to have clockId = 1, got: " # debug_show (tid2b.clockId));
    };
  },
);
