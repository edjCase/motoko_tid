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

  if (TID.equal(actualTid, expectedTid)) {
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
  "TID - Valid Example 1 from Spec",
  func() {
    testTidRoundtrip("3jzfcijpj2z2a");
  },
);

test(
  "TID - Valid Example 2 from Spec",
  func() {
    testTidRoundtrip("7777777777777");
  },
);

test(
  "TID - Valid Example 3 from Spec",
  func() {
    testTidRoundtrip("3zzzzzzzzzzzz");
  },
);

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
    testTidRoundtrip("7777777777777");
    testTidRoundtrip("3zzzzzzzzzzzz");
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
