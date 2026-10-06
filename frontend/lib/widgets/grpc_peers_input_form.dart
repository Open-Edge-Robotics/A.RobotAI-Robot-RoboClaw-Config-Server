import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/peer_config.dart';
import '../utils/localization.dart';

class GrpcPeersInputForm extends StatefulWidget {
  final TextEditingController controller;
  final bool isEditing;

  const GrpcPeersInputForm({
    super.key,
    required this.controller,
    required this.isEditing,
  });

  @override
  State<GrpcPeersInputForm> createState() => _GrpcPeersInputFormState();
}

class _GrpcPeersInputFormState extends State<GrpcPeersInputForm> {
  List<PeerConfig> _peers = [];
  bool _isUpdatingFromInternal = false;
  int _rebuildCounter = 0;

  @override
  void initState() {
    super.initState();
    _parseFromController();
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void didUpdateWidget(covariant GrpcPeersInputForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
      _parseFromController();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    if (_isUpdatingFromInternal) return;
    setState(() {
      _parseFromController();
    });
  }

  void _parseFromController() {
    _peers = PeerConfig.parsePeersJson(widget.controller.text);
    _rebuildCounter++;
  }

  void _updateController() {
    _isUpdatingFromInternal = true;
    widget.controller.text = PeerConfig.serializePeersJson(_peers);
    _isUpdatingFromInternal = false;
  }

  void _addPeer() {
    setState(() {
      _peers.add(
        PeerConfig(
          name: 'Robot_${_peers.length + 1}',
          host: '127.0.0.1',
          port: 50051,
          description: '',
          role: '',
        ),
      );
      _updateController();
    });
  }

  void _removePeer(int index) {
    setState(() {
      _peers.removeAt(index);
      _updateController();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '동료 로봇 피어 설정'.tr,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: Colors.white70,
          ),
        ),
        const SizedBox(height: 8),
        if (_peers.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(8),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white10),
            ),
            child: Center(
              child: Text(
                '등록된 동료 로봇이 없습니다.'.tr,
                style: const TextStyle(color: Colors.white38, fontSize: 13),
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _peers.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final peer = _peers[index];
              return _buildPeerCard(index, peer);
            },
          ),
        const SizedBox(height: 12),
        if (widget.isEditing)
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _addPeer,
              icon: const Icon(Icons.add, size: 18),
              label: Text('동료 로봇 추가'.tr),
              style: OutlinedButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.primary,
                side: BorderSide(
                  color: Theme.of(context).colorScheme.primary,
                  width: 1.2,
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPeerCard(int index, PeerConfig peer) {
    return Container(
      key: ValueKey('peer_${_rebuildCounter}_$index'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.white.withAlpha(5)
            : Colors.black.withAlpha(5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Theme.of(context).dividerColor, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${'로봇 #'.tr}${index + 1}',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              if (widget.isEditing)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Colors.redAccent,
                    size: 20,
                  ),
                  onPressed: () => _removePeer(index),
                  tooltip: '삭제'.tr,
                ),
            ],
          ),
          const SizedBox(height: 8),
          // 첫 번째 행: 이름, 호스트, 포트
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextFormField(
                  initialValue: peer.name,
                  enabled: widget.isEditing,
                  decoration: InputDecoration(
                    labelText: '로봇 이름'.tr,
                    hintText: '예: Robot_A'.tr,
                    isDense: true,
                  ),
                  onChanged: (val) {
                    peer.name = val;
                    _updateController();
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 3,
                child: TextFormField(
                  initialValue: peer.host,
                  enabled: widget.isEditing,
                  decoration: InputDecoration(
                    labelText: '호스트 (IP/도메인)'.tr,
                    hintText: '예: 192.168.1.100'.tr,
                    isDense: true,
                  ),
                  onChanged: (val) {
                    peer.host = val;
                    _updateController();
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: TextFormField(
                  initialValue: peer.port.toString(),
                  enabled: widget.isEditing,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: '포트 번호'.tr,
                    hintText: '50051',
                    isDense: true,
                  ),
                  onChanged: (val) {
                    final p = int.tryParse(val) ?? 50051;
                    peer.port = p;
                    _updateController();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 두 번째 행: 설명, 역할
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextFormField(
                  initialValue: peer.description,
                  enabled: widget.isEditing,
                  decoration: InputDecoration(
                    labelText: '로봇 설명 (사전 정보)'.tr,
                    hintText: '예: 집게 팔 장착 매니퓰레이터'.tr,
                    isDense: true,
                  ),
                  onChanged: (val) {
                    peer.description = val;
                    _updateController();
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: TextFormField(
                  initialValue: peer.role,
                  enabled: widget.isEditing,
                  decoration: InputDecoration(
                    labelText: '역할 / 타입'.tr,
                    hintText: '예: manipulator'.tr,
                    isDense: true,
                  ),
                  onChanged: (val) {
                    peer.role = val;
                    _updateController();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
