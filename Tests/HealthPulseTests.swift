import Testing

// MARK: - Smoke test
//
// Confirms the HealthPulseTests target is wired up and the Swift Testing
// framework runs. Real coverage is added by later test tasks.

@Test("Test target is wired up")
func testTargetSmoke() {
    #expect(1 + 1 == 2)
}
