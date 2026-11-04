import 'package:flutter/material.dart';
import '../../sos/sos_packet.dart';

class EmergencyActionPanel extends StatelessWidget {
  final SosPacket? activeSos;
  final VoidCallback onTriggerSos;
  final VoidCallback onCancelSos;

  const EmergencyActionPanel({
    super.key,
    required this.activeSos,
    required this.onTriggerSos,
    required this.onCancelSos,
  });

  @override
  Widget build(BuildContext context) {
    final bool isSosActive = activeSos != null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isSosActive ? const Color(0xFF450A0A) : const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSosActive ? const Color(0xFFFF2E4C) : Colors.white.withOpacity(0.12),
          width: isSosActive ? 2.0 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!isSosActive) ...[
            ElevatedButton(
              onPressed: onTriggerSos,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 6,
                shadowColor: Colors.redAccent.withOpacity(0.5),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.sos_rounded, size: 28),
                  SizedBox(width: 8),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'SEND ONE-TAP EMERGENCY SOS',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            Row(
              children: [
                const Icon(Icons.emergency_rounded, color: Color(0xFFFF2E4C), size: 24),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'EMERGENCY SOS BROADCAST ACTIVE',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFFFF2E4C),
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Step Progress Workflow: CREATED -> QUEUED -> RELAYED -> RECEIVED BY RESPONDER
            _buildStatusStep(
              stepNumber: 1,
              label: 'SOS CREATED',
              isDone: true,
              isActive: activeSos!.status == SosStatus.created,
            ),
            _buildStatusStep(
              stepNumber: 2,
              label: 'QUEUED IN MESH OUTBOX',
              isDone: activeSos!.status.index >= SosStatus.queued.index,
              isActive: activeSos!.status == SosStatus.queued,
            ),
            _buildStatusStep(
              stepNumber: 3,
              label: 'RELAYED VIA P2P MESH',
              isDone: activeSos!.status.index >= SosStatus.relayed.index,
              isActive: activeSos!.status == SosStatus.relayed,
            ),
            _buildStatusStep(
              stepNumber: 4,
              label: 'RECEIVED BY RESPONDER (EOC)',
              isDone: activeSos!.status == SosStatus.receivedByResponder,
              isActive: activeSos!.status == SosStatus.receivedByResponder,
            ),

            if (activeSos!.responderAckMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF065F46),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF10B981)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.verified_user_rounded, color: const Color(0xFF10B981), size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Responder ACK: "${activeSos!.responderAckMessage}"',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 14),
            // Phase 0 safety: no simulated responder ACK. An ACK may only
            // come from a real server / mesh confirmation (Phase 2).
            Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: onCancelSos,
                    icon: const Icon(Icons.cancel_outlined, size: 16),
                    label: const Text('Cancel SOS', style: TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(foregroundColor: Colors.white70),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusStep({
    required int stepNumber,
    required String label,
    required bool isDone,
    required bool isActive,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            isDone ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            size: 16,
            color: isDone ? const Color(0xFF10B981) : Colors.white38,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isDone ? FontWeight.bold : FontWeight.normal,
                color: isDone ? Colors.white : Colors.white54,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
