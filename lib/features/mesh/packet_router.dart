import 'mesh_packet.dart';
import 'store_forward_queue.dart';

class RoutingDecision {
  final bool shouldForward;
  final String reason;
  final MeshPacket updatedPacket;

  const RoutingDecision({
    required this.shouldForward,
    required this.reason,
    required this.updatedPacket,
  });
}

class PacketRouter {
  final StoreForwardQueue _queue;

  PacketRouter({StoreForwardQueue? queue})
      : _queue = queue ?? StoreForwardQueue();

  StoreForwardQueue get queue => _queue;

  /// Evaluates incoming packet for duplicate suppression, TTL decrementing, and priority routing.
  RoutingDecision routePacket(MeshPacket packet, {int userBattery = 100}) {
    // 1. Check duplicate
    if (_queue.isDuplicate(packet.id)) {
      return RoutingDecision(
        shouldForward: false,
        reason: 'Duplicate packet ID detected. Dropped to avoid network loop.',
        updatedPacket: packet,
      );
    }

    // 2. Check TTL expiration
    if (packet.ttl <= 1) {
      return RoutingDecision(
        shouldForward: false,
        reason: 'TTL expired (${packet.ttl}). Dropped to avoid infinite propagation.',
        updatedPacket: packet.copyWith(ttl: 0),
      );
    }

    // 3. Low Battery Saver Rule: If battery < 15%, drop LOW/MEDIUM packets
    if (userBattery < 15 &&
        (packet.priority == PacketPriority.low ||
            packet.priority == PacketPriority.medium)) {
      return RoutingDecision(
        shouldForward: false,
        reason: 'Battery critical ($userBattery%). Low priority packet suppressed.',
        updatedPacket: packet,
      );
    }

    // 4. Decrement TTL & increment Hop Count
    final forwardedPacket = packet.copyWith(
      ttl: packet.ttl - 1,
      hopCount: packet.hopCount + 1,
    );

    _queue.enqueuePacket(forwardedPacket);

    return RoutingDecision(
      shouldForward: true,
      reason: 'Packet accepted into Store & Forward outbox. Priority: ${packet.priority.name.toUpperCase()}',
      updatedPacket: forwardedPacket,
    );
  }
}
