//
//  StubThrowingFunctionTest.swift
//  Cuckoo
//
//  Created by Filip Dolnik on 04.07.16.
//  Copyright © 2016 Brightify. All rights reserved.
//

import XCTest
import Cuckoo

class StubThrowingFunctionTest: XCTestCase {
    
    func testThen() {
        let mock = MockTestedClass()
        stub(mock) { mock in
            when(mock.withThrows()).then {
                return 2
            }
        }
        
        XCTAssertEqual(try! mock.withThrows(), 2)
    }
    
    func testThenReturn() {
        let mock = MockTestedClass()
        stub(mock) { mock in
            when(mock.withThrows()).thenReturn(2)
        }
        
        XCTAssertEqual(try! mock.withThrows(), 2)
    }
    
    func testThenCallRealImplementation() {
        let mock = MockTestedClass().spy(on: TestedClass())
        stub(mock) { mock in
            when(mock.withThrows()).thenCallRealImplementation()
        }
        
        XCTAssertEqual(try! mock.withThrows(), 0)
    }
    
    func testThenThrow() {
        let mock = MockTestedClass()
        stub(mock) { mock in
            when(mock.withThrows()).thenThrow(TestError.Unknown)
        }
        
        var catched = false
        do {
            try mock.withThrows()
        } catch {
            catched = true
        }
        
        XCTAssertTrue(catched)
    }
    
    private enum TestError: ErrorType {
        case Unknown
    }
}