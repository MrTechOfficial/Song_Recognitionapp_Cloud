import Flutter
import Foundation
import UIKit
import XCTest
@testable import Runner

class RunnerTests: XCTestCase {

  func testLegacyRecognitionSettingsKeepSavedValues() throws {
    let json = Data(#"{"language":"fr","environment":"outdoors","durationSeconds":12,"backendURL":"https://example.com/recognize"}"#.utf8)
    let settings = try JSONDecoder().decode(RecztRecognitionSettings.self, from: json)
    XCTAssertEqual(settings.language, "fr")
    XCTAssertEqual(settings.environment, "outdoors")
    XCTAssertEqual(settings.durationSeconds, 12)
    XCTAssertEqual(settings.backendURL, "https://example.com/recognize")
    XCTAssertNil(settings.seasonalTheme)
  }

  func testLegacyActivityAttributesDecodeWithoutATheme() throws {
    let json = Data(#"{"sessionID":"existing-session","startedAt":0,"environment":"quiet"}"#.utf8)
    let attributes = try JSONDecoder().decode(RecztRecognitionAttributes.self, from: json)
    XCTAssertNil(attributes.seasonalTheme)
    XCTAssertFalse(attributes.isChristmas)
    XCTAssertFalse(attributes.isHalloween)
  }

  func testChristmasThemeSurvivesActivityAndSettingsEncoding() throws {
    let attributes = RecztRecognitionAttributes(
      sessionID: "holiday-session", startedAt: Date(), environment: "quiet", seasonalTheme: "christmas"
    )
    let restored = try JSONDecoder().decode(
      RecztRecognitionAttributes.self, from: JSONEncoder().encode(attributes)
    )
    XCTAssertTrue(restored.isChristmas)
    XCTAssertFalse(restored.isHalloween)
    var settings = RecztRecognitionSettings()
    settings.seasonalTheme = "christmas"
    let restoredSettings = try JSONDecoder().decode(
      RecztRecognitionSettings.self, from: JSONEncoder().encode(settings)
    )
    XCTAssertEqual(restoredSettings.seasonalTheme, "christmas")
  }

  func testHalloweenActivityKeepsItsThemeWithoutAffectingRecognitionContent() throws {
    let attributes = RecztRecognitionAttributes(
      sessionID: "halloween-session", startedAt: Date(), environment: "outdoors", seasonalTheme: "halloween"
    )
    let restored = try JSONDecoder().decode(
      RecztRecognitionAttributes.self, from: JSONEncoder().encode(attributes)
    )
    XCTAssertTrue(restored.isHalloween)
    XCTAssertFalse(restored.isChristmas)
    XCTAssertEqual(restored.sessionID, "halloween-session")
    XCTAssertEqual(restored.environment, "outdoors")
  }

  func testListeningStateHasARealDeadlineAndLegacyContentStillDecodes() throws {
    let before = Date()
    let state = RecztRecognitionAttributes.ContentState.listening(secondsRemaining: 10, source: "app")
    let after = Date()
    XCTAssertNotNil(state.listeningEndsAt)
    XCTAssertGreaterThanOrEqual(state.listeningEndsAt!, before.addingTimeInterval(10))
    XCTAssertLessThanOrEqual(state.listeningEndsAt!, after.addingTimeInterval(10))
    let restored = try JSONDecoder().decode(RecztRecognitionAttributes.ContentState.self,
      from: JSONEncoder().encode(state))
    XCTAssertEqual(restored.listeningEndsAt, state.listeningEndsAt)
    let legacy = Data(#"{"phase":"listening","title":"Reczt","artist":"","secondsRemaining":10,"source":"app"}"#.utf8)
    XCTAssertNil(try JSONDecoder().decode(RecztRecognitionAttributes.ContentState.self, from: legacy).listeningEndsAt)
  }

  func testActivityUsesAppLanguageAndLocalizedOutcomesWithoutDeviceLocale() throws {
    var state = RecztRecognitionAttributes.ContentState.listening(
      secondsRemaining: 8, source: "app", language: "es")
    state.redirecting = true
    let restored = try JSONDecoder().decode(RecztRecognitionAttributes.ContentState.self,
      from: JSONEncoder().encode(state))
    XCTAssertEqual(restored.language, "es")
    XCTAssertEqual(restored.redirecting, true)
    XCTAssertEqual(RecztRecognitionAttributes.localizedText("activity_found", language: "es-MX"), "¡Canción encontrada!")
    XCTAssertEqual(RecztRecognitionAttributes.localizedText("activity_redirecting", language: "fr"), "Redirection en cours !")
    XCTAssertEqual(RecztRecognitionAttributes.localizedText("activity_found", language: "unknown"), "Song found!")
    XCTAssertEqual(RecztRecognitionAttributes.dictionaries.count, 15)
    for values in RecztRecognitionAttributes.dictionaries.values {
      XCTAssertFalse(values["activity_no_match_hint", default: ""].isEmpty)
    }
  }

}
