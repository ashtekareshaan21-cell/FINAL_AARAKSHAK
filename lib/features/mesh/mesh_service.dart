import 'dart:async';
import 'mesh_packet.dart';
import 'packet_router.dart';

enum MeshConnectivityState {
  disconnected,
  discoveringPeers,
  connected,
}

class MeshService {
  final PacketRouter _router;
  MeshConnectivityState _connectivityState = MeshConnectivityState.connected;
  int _connectedPeers = 3;

  final _meshStateController = StreamController<MeshConnectivityState>.broadcast();
  final _incomingPacketController = StreamController<MeshPacket>.broadcast();

  MeshService({PacketRouter? router}) : _router = router ?? PacketRouter();

  PacketRouter get router => _router;
  MeshConnectivityState get connectivityState => _connectivityState;
  int get connectedPeers => _connectedPeers;

  Stream<MeshConnectivityState> get connectivityStream => _meshStateController.stream;
  Stream<MeshPacket> get incomingPacketStream => _incomingPacketController.stream;

  void updateMeshConnectivity(MeshConnectivityState state, int peers) {
    _connectivityState = state;
    _connectedPeers = peers;
    _meshStateController.add(_connectivityState);
  }

  Future<RoutingDecision> sendPacket(MeshPacket packet, {int battery = 100}) async {
    final decision = _router.routePacket(packet, userBattery: battery);
    if (decision.shouldForward) {
      _incomingPacketController.add(decision.updatedPacket);
    }
    return decision;
  }

  void dispose() {
    _meshStateController.close();
    _incomingPacketController.close();
  }
}
