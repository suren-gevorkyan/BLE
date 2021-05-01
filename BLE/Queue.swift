//
//  Queue.swift
//  BLE
//
//  Created by Suren Gevorkyan on 3/29/21.
//

import Foundation

class Queue<T: Equatable> {
    private var first: ListNode<T>?
    private var last: ListNode<T>?
    
    private(set) var count: Int = 0
    
    var isEmpty: Bool { count == 0 }
    
    func push(_ value: T) {
        let newNode = ListNode(value)
        if let l = last {
            l.next = newNode
            last = newNode
        } else {
            first = newNode
            last = first
        }
        count += 1
    }
    
    func pushValues(_ values: [T]) {
        for value in values {
            let newNode = ListNode(value)
            if let l = last {
                l.next = newNode
                last = newNode
            } else {
                first = newNode
                last = first
            }
            count += 1
        }
    }
    
    func head() -> T? {
        return first?.value
    }
    
    @discardableResult
    func pop() -> T? {
        var ret: T? = nil
        if let f = first {
            ret = f.value
            first = f.next
            if first == nil {
                last = nil
            }
            count -= 1
        }
        return ret
    }
    
    @discardableResult
    func remove(value: T) -> Bool {
        guard let head = first else { return false }
        
        var didRemove = false
        if head.value == value {
            let _ = pop()
            didRemove = true
        } else {
            var current: ListNode? = head
            while current?.next != nil {
                let next = current!.next!
                if next.value == value {
                    current!.next = next.next
                    count -= 1
                    if next == last {
                        last = nil
                    }
                    didRemove = true
                    break
                }
                current = current?.next
            }
        }
        
        return didRemove
    }
    
    func removeAll() {
        if let head = first {
            var current: ListNode? = head
            while current?.next != nil {
                let next = current?.next
                current!.next = nil
                current = next
            }
            first = nil
            last = nil
            count = 0
        }
    }
}

class ListNode<T>: NSObject {
    private(set) var value: T
    var next: ListNode<T>?
    
    init(_ value: T) {
        self.value = value
    }
}
