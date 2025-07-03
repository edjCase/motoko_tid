import TID "../src";
import Debug "mo:base/Debug";
import Text "mo:new-base/Text";
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
    if (TID.compare(tid1, tid2) >= 0) {
      Debug.trap("Expected tid1 < tid2");
    };

    if (TID.compare(tid2, tid1) <= 0) {
      Debug.trap("Expected tid2 > tid1");
    };

    if (TID.compare(tid1, tid1) != 0) {
      Debug.trap("Expected tid1 == tid1");
    };

    if (TID.compare(tid2, tid3) >= 0) {
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
    let generator = TID.buildDefaultGenerator();
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
  "TID Generator - Custom Initial Clock ID",
  func() {
    let generator = TID.buildGenerator(42);
    let tid = generator.next();

    // First TID should have clockId = 42
    if (tid.clockId != 42) {
      Debug.trap("Expected first TID from custom generator to have clockId = 42, got: " # debug_show (tid.clockId));
    };
  },
);

test(
  "TID Generator - Clock ID Wrapping",
  func() {
    // Test wrapping behavior by starting near max value
    let generator = TID.buildGenerator(1022); // MAX_CLOCK_ID is 1023

    let tid1 = generator.next(); // Should be 1022
    if (tid1.clockId != 1022) {
      Debug.trap("Expected clockId = 1022, got: " # debug_show (tid1.clockId));
    };

    let tid2 = generator.next(); // Should be  1023
    if (tid2.clockId != 1023) {
      Debug.trap("Expected clockId to wrap to 1023, got: " # debug_show (tid2.clockId));
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
    let generator = TID.buildGenerator(0);

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
    let generator = TID.buildDefaultGenerator();

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
    let generator = TID.buildGenerator(100);

    let tid1 = generator.next(); // clockId = 101
    let tid2 = generator.next(); // clockId = 102
    let tid3 = generator.next(); // clockId = 103

    // Since they have same timestamp, ordering should be by clockId
    if (TID.compare(tid1, tid2) >= 0) {
      Debug.trap("Expected tid1 < tid2 (same timestamp, sequential clock IDs)");
    };

    if (TID.compare(tid2, tid3) >= 0) {
      Debug.trap("Expected tid2 < tid3 (same timestamp, sequential clock IDs)");
    };

    if (TID.compare(tid1, tid3) >= 0) {
      Debug.trap("Expected tid1 < tid3 (same timestamp, sequential clock IDs)");
    };
  },
);

test(
  "TID Generator - Multiple Generators Independence",
  func() {
    let gen1 = TID.buildGenerator(10);
    let gen2 = TID.buildGenerator(20);

    let tid1a = gen1.next(); // clockId = 10
    let tid2a = gen2.next(); // clockId = 20
    let tid1b = gen1.next(); // clockId = 11
    let tid2b = gen2.next(); // clockId = 21

    // Verify independence - each generator maintains its own clock state
    if (tid1a.clockId != 10) {
      Debug.trap("Expected gen1 first TID to have clockId = 10, got: " # debug_show (tid1a.clockId));
    };

    if (tid2a.clockId != 20) {
      Debug.trap("Expected gen2 first TID to have clockId = 20, got: " # debug_show (tid2a.clockId));
    };

    if (tid1b.clockId != 11) {
      Debug.trap("Expected gen1 second TID to have clockId = 11, got: " # debug_show (tid1b.clockId));
    };

    if (tid2b.clockId != 21) {
      Debug.trap("Expected gen2 second TID to have clockId = 21, got: " # debug_show (tid2b.clockId));
    };
  },
);

test(
  "TID Generator - Edge Case: Max Initial Clock ID",
  func() {
    // Start with maximum clock ID
    let generator = TID.buildGenerator(1024);

    let tid1 = generator.next(); // Should wrap to 0
    if (tid1.clockId != 0) {
      Debug.trap("Expected clockId to wrap to 0 when starting at max, got: " # debug_show (tid1.clockId));
    };

    let tid2 = generator.next(); // Should be 1
    if (tid2.clockId != 1) {
      Debug.trap("Expected clockId = 1 after wrapping, got: " # debug_show (tid2.clockId));
    };
  },
);

test(
  "TID Generator - Direct Constructor Usage",
  func() {
    // Test using the Generator constructor directly with known values
    let fixedTime = 1640995200000000; // Fixed timestamp in nanoseconds
    let generator = TID.Generator(fixedTime, 6);

    let tid1 = generator.next();
    let tid2 = generator.next();

    // Both should have the same timestamp (converted to microseconds)
    let expectedTimestamp = 1640995200000; // nanoseconds / 1000 = microseconds
    if (tid1.timestamp != expectedTimestamp) {
      Debug.trap("Expected timestamp " # debug_show (expectedTimestamp) # ", got: " # debug_show (tid1.timestamp));
    };

    if (tid2.timestamp != expectedTimestamp) {
      Debug.trap("Expected same timestamp for both TIDs from same generator");
    };

    // Clock IDs should be 6 and 7 (incremented from initial 5)
    if (tid1.clockId != 6) {
      Debug.trap("Expected first TID clockId = 6, got: " # debug_show (tid1.clockId));
    };

    if (tid2.clockId != 7) {
      Debug.trap("Expected second TID clockId = 7, got: " # debug_show (tid2.clockId));
    };
  },
);
