import Foundation

protocol LongPressCancellation: AnyObject { func cancel() }
protocol LongPressScheduler: AnyObject {
    var now: Double { get }
    func schedule(at deadline: Double, _ action: @escaping () -> Void) -> LongPressCancellation
}

// One-shot sources run on the engine's existing serial queue; never on the tap thread.
final class DispatchLongPressScheduler: LongPressScheduler {
    private let queue: DispatchQueue
    private let clock: () -> Double
    init(queue: DispatchQueue, clock: @escaping () -> Double) { self.queue = queue; self.clock = clock }
    var now: Double { clock() }
    func schedule(at deadline: Double, _ action: @escaping () -> Void) -> LongPressCancellation {
        let ticket = Ticket(queue: queue)
        ticket.source?.schedule(deadline: .now() + max(0, deadline - now), leeway: .milliseconds(1))
        ticket.source?.setEventHandler { [weak ticket] in ticket?.cancel(); action() }
        ticket.source?.resume()
        return ticket
    }
    private final class Ticket: LongPressCancellation {
        var source: DispatchSourceTimer?
        init(queue: DispatchQueue) { source = DispatchSource.makeTimerSource(queue: queue) }
        func cancel() { source?.setEventHandler {}; source?.cancel(); source = nil }
        deinit { cancel() }
    }
}
