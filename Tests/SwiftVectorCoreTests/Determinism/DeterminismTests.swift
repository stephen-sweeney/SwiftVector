//
//  DeterminismTests.swift
//  SwiftVectorCoreTests
//
//  Created by Stephen Sweeney
//  Copyright © 2026 Flightworks Aerial LLC. All rights reserved.
//

import Testing
import Foundation
@testable import SwiftVectorCore
@testable import SwiftVectorTesting

// MARK: - Clock Tests

@Suite("Clock Protocol")
struct ClockTests {
    
    @Test("SystemClock returns current time")
    func systemClockReturnsCurrentTime() {
        let clock = SystemClock()
        let before = Date()
        let clockTime = clock.now()
        let after = Date()
        
        #expect(clockTime >= before)
        #expect(clockTime <= after)
    }
    
    @Test("MockClock returns fixed time")
    func mockClockReturnsFixedTime() {
        let fixedDate = Date(timeIntervalSince1970: 1000)
        let clock = MockClock(fixed: fixedDate)
        
        #expect(clock.now() == fixedDate)
        #expect(clock.now() == fixedDate)  // Stable across calls
    }
    
    @Test("MockClock advances time")
    func mockClockAdvancesTime() {
        let clock = MockClock(fixed: Date(timeIntervalSince1970: 0))
        
        clock.advance(by: 60)  // One minute
        #expect(clock.now() == Date(timeIntervalSince1970: 60))
        
        clock.advance(by: 3600)  // One hour
        #expect(clock.now() == Date(timeIntervalSince1970: 3660))
    }
    
    @Test("MockClock can be set to specific time")
    func mockClockCanBeSet() {
        let clock = MockClock()
        let targetDate = Date(timeIntervalSince1970: 999999)
        
        clock.set(targetDate)
        #expect(clock.now() == targetDate)
    }
    
    @Test("MockClock reset returns to epoch")
    func mockClockReset() {
        let clock = MockClock(fixed: Date(timeIntervalSince1970: 5000))
        clock.advance(by: 1000)
        
        clock.reset()
        #expect(clock.now() == Date(timeIntervalSince1970: 0))
    }
    
    @Test("MockClock is stable across repeated access")
    func mockClockStability() {
        let clock = MockClock(fixed: Date(timeIntervalSince1970: 12345))
        
        let times = (0..<100).map { _ in clock.now() }
        let allEqual = times.allSatisfy { $0 == times[0] }
        
        #expect(allEqual, "MockClock should return same time until advanced")
    }
}

// MARK: - UUIDGenerator Tests

@Suite("UUIDGenerator Protocol")
struct UUIDGeneratorTests {
    
    @Test("SystemUUIDGenerator produces unique UUIDs")
    func systemGeneratorProducesUniqueUUIDs() {
        let generator = SystemUUIDGenerator()
        
        let uuids = (0..<100).map { _ in generator.next() }
        let uniqueCount = Set(uuids).count
        
        #expect(uniqueCount == 100, "All generated UUIDs should be unique")
    }
    
    @Test("MockUUIDGenerator returns sequence in order")
    func mockGeneratorReturnsSequence() {
        let id1 = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let id2 = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        let id3 = UUID(uuidString: "00000000-0000-0000-0000-000000000003")!
        
        let generator = MockUUIDGenerator(sequence: [id1, id2, id3])
        
        #expect(generator.next() == id1)
        #expect(generator.next() == id2)
        #expect(generator.next() == id3)
    }
    
    @Test("MockUUIDGenerator tracks call count")
    func mockGeneratorTracksCallCount() {
        let generator = MockUUIDGenerator(sequential: 1, count: 10)
        
        #expect(generator.callCount == 0)
        
        _ = generator.next()
        #expect(generator.callCount == 1)
        
        _ = generator.next()
        _ = generator.next()
        #expect(generator.callCount == 3)
    }
    
    @Test("MockUUIDGenerator sequential mode produces predictable IDs")
    func mockGeneratorSequentialMode() {
        let generator = MockUUIDGenerator(sequential: 1, count: 3)
        
        #expect(generator.next() == UUID(uuidString: "00000000-0000-0000-0000-000000000001")!)
        #expect(generator.next() == UUID(uuidString: "00000000-0000-0000-0000-000000000002")!)
        #expect(generator.next() == UUID(uuidString: "00000000-0000-0000-0000-000000000003")!)
    }
    
    @Test("MockUUIDGenerator reset restarts sequence")
    func mockGeneratorReset() {
        let id1 = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let generator = MockUUIDGenerator(sequence: [id1])
        
        #expect(generator.next() == id1)
        
        generator.reset()
        #expect(generator.callCount == 0)
        #expect(generator.next() == id1)
    }
    
    @Test("MockUUIDGenerator reports remaining count")
    func mockGeneratorRemainingCount() {
        let generator = MockUUIDGenerator(sequential: 1, count: 5)
        
        #expect(generator.remaining == 5)
        _ = generator.next()
        #expect(generator.remaining == 4)
        _ = generator.next()
        _ = generator.next()
        #expect(generator.remaining == 2)
    }
}

// MARK: - RandomSource Tests

@Suite("RandomSource Protocol")
struct RandomSourceTests {
    
    @Test("SystemRandomSource produces values in range")
    func systemRandomProducesValuesInRange() {
        let random = SystemRandomSource()
        
        for _ in 0..<100 {
            let value = random.nextInt(in: 10..<20)
            #expect(value >= 10 && value < 20)
        }
        
        for _ in 0..<100 {
            let value = random.nextInt(in: 1...6)
            #expect(value >= 1 && value <= 6)
        }
        
        for _ in 0..<100 {
            let value = random.nextDouble()
            #expect(value >= 0.0 && value < 1.0)
        }
    }
    
    @Test("MockRandomSource returns int sequence")
    func mockRandomReturnsIntSequence() {
        let random = MockRandomSource(intSequence: [5, 10, 15])
        
        #expect(random.nextInt(in: 0..<100) == 5)
        #expect(random.nextInt(in: 0..<100) == 10)
        #expect(random.nextInt(in: 0..<100) == 15)
    }
    
    @Test("MockRandomSource clamps values to range")
    func mockRandomClampsToRange() {
        let random = MockRandomSource(intSequence: [0, 50, 100])
        
        // Value 0 is within range
        #expect(random.nextInt(in: 0..<10) == 0)
        
        // Value 50 clamped to range max (9)
        #expect(random.nextInt(in: 0..<10) == 9)
        
        // Value 100 clamped to range max (9)
        #expect(random.nextInt(in: 0..<10) == 9)
    }
    
    @Test("MockRandomSource returns double sequence")
    func mockRandomReturnsDoubleSequence() {
        let random = MockRandomSource(intSequence: [], doubleSequence: [0.0, 0.5, 0.99])
        
        #expect(random.nextDouble() == 0.0)
        #expect(random.nextDouble() == 0.5)
        #expect(random.nextDouble() == 0.99)
    }
    
    @Test("MockRandomSource nextBool uses double threshold")
    func mockRandomNextBool() {
        let random = MockRandomSource(doubleSequence: [0.0, 0.49, 0.5, 0.99])
        
        #expect(random.nextBool() == true)   // 0.0 < 0.5
        #expect(random.nextBool() == true)   // 0.49 < 0.5
        #expect(random.nextBool() == false)  // 0.5 >= 0.5
        #expect(random.nextBool() == false)  // 0.99 >= 0.5
    }
    
    @Test("MockRandomSource seeded mode is deterministic")
    func mockRandomSeededDeterminism() {
        let random1 = MockRandomSource(seed: 42)
        let random2 = MockRandomSource(seed: 42)
        
        let sequence1 = (0..<10).map { _ in random1.nextInt(in: 0..<1000) }
        let sequence2 = (0..<10).map { _ in random2.nextInt(in: 0..<1000) }
        
        #expect(sequence1 == sequence2, "Same seed should produce same sequence")
    }
    
    @Test("MockRandomSource seeded reset reproduces sequence")
    func mockRandomSeededReset() {
        let random = MockRandomSource(seed: 42)
        
        let first = (0..<5).map { _ in random.nextInt(in: 0..<1000) }
        random.reset()
        let second = (0..<5).map { _ in random.nextInt(in: 0..<1000) }
        
        #expect(first == second, "Reset should reproduce same sequence")
    }
    
    @Test("MockRandomSource tracks call counts")
    func mockRandomTracksCallCounts() {
        let random = MockRandomSource(intSequence: [1, 2, 3], doubleSequence: [0.1, 0.2])
        
        #expect(random.intCallCount == 0)
        #expect(random.doubleCallCount == 0)
        
        _ = random.nextInt(in: 0..<10)
        _ = random.nextInt(in: 0..<10)
        #expect(random.intCallCount == 2)
        
        _ = random.nextDouble()
        #expect(random.doubleCallCount == 1)
    }
    
    @Test("RandomSource randomElement selects from collection")
    func randomSourceRandomElement() {
        let random = MockRandomSource(intSequence: [0, 2, 4])
        let items = ["a", "b", "c", "d", "e"]
        
        #expect(random.randomElement(from: items) == "a")  // index 0
        #expect(random.randomElement(from: items) == "c")  // index 2
        #expect(random.randomElement(from: items) == "e")  // index 4
    }
    
    @Test("RandomSource randomElement returns nil for empty collection")
    func randomSourceRandomElementEmpty() {
        let random = MockRandomSource(intSequence: [0])
        let empty: [String] = []
        
        #expect(random.randomElement(from: empty) == nil)
    }
    
    @Test("RandomSource shuffled is deterministic with seeded source")
    func randomSourceShuffledDeterministic() {
        let random1 = MockRandomSource(seed: 123)
        let random2 = MockRandomSource(seed: 123)
        
        let items = [1, 2, 3, 4, 5]
        
        let shuffled1 = random1.shuffled(items)
        let shuffled2 = random2.shuffled(items)
        
        #expect(shuffled1 == shuffled2, "Same seed should produce same shuffle")
    }
}

// MARK: - Integration Tests

@Suite("Determinism Integration")
struct DeterminismIntegrationTests {
    
    @Test("All primitives can be injected together")
    func allPrimitivesInjectable() {
        // Simulates what an Orchestrator would receive
        struct DeterministicContext {
            let clock: any Clock
            let uuidGenerator: any UUIDGenerator
            let randomSource: any RandomSource
        }
        
        let context = DeterministicContext(
            clock: MockClock(fixed: Date(timeIntervalSince1970: 0)),
            uuidGenerator: MockUUIDGenerator(sequential: 1),
            randomSource: MockRandomSource(seed: 42)
        )
        
        // All should be usable
        let time = context.clock.now()
        let id = context.uuidGenerator.next()
        let value = context.randomSource.nextInt(in: 0..<100)
        
        #expect(time == Date(timeIntervalSince1970: 0))
        #expect(id == UUID(uuidString: "00000000-0000-0000-0000-000000000001")!)
        #expect(value >= 0 && value < 100)
    }
    
    @Test("Primitives produce identical results after reset")
    func primitivesResetForReplay() {
        let clock = MockClock(fixed: Date(timeIntervalSince1970: 0))
        let uuids = MockUUIDGenerator(sequential: 1, count: 10)
        let random = MockRandomSource(seed: 42)
        
        // First run
        clock.advance(by: 100)
        let time1 = clock.now()
        let id1 = uuids.next()
        let val1 = random.nextInt(in: 0..<1000)
        
        // Reset all
        clock.reset()
        clock.advance(by: 100)
        uuids.reset()
        random.reset()
        
        // Second run should match
        let time2 = clock.now()
        let id2 = uuids.next()
        let val2 = random.nextInt(in: 0..<1000)
        
        #expect(time1 == time2)
        #expect(id1 == id2)
        #expect(val1 == val2)
    }
}
