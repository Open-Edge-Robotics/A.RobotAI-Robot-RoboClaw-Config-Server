import 'package:flutter/material.dart';

import '../utils/localization.dart';
import 'config_section_header.dart';

class ConfigCameraSection extends StatelessWidget {
  final bool isEditing;
  final TextEditingController cameraTopicCtrl;
  final bool useVision;
  final ValueChanged<bool> onUseVisionChanged;
  final TextEditingController visionModelPathCtrl;
  final TextEditingController gripperCameraTopicCtrl;
  final TextEditingController gripperDepthTopicCtrl;
  final TextEditingController gripperCameraInfoTopicCtrl;
  final TextEditingController gripperPointcloudTopicCtrl;
  final bool useGripperVision;
  final ValueChanged<bool> onUseGripperVisionChanged;
  final TextEditingController gripperVisionMaxInferenceHzCtrl;
  final TextEditingController lidarTopicCtrl;
  final TextEditingController imuTopicCtrl;

  const ConfigCameraSection({
    super.key,
    required this.isEditing,
    required this.cameraTopicCtrl,
    required this.useVision,
    required this.onUseVisionChanged,
    required this.visionModelPathCtrl,
    required this.gripperCameraTopicCtrl,
    required this.gripperDepthTopicCtrl,
    required this.gripperCameraInfoTopicCtrl,
    required this.gripperPointcloudTopicCtrl,
    required this.useGripperVision,
    required this.onUseGripperVisionChanged,
    required this.gripperVisionMaxInferenceHzCtrl,
    required this.lidarTopicCtrl,
    required this.imuTopicCtrl,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ConfigSectionHeader('7. 카메라 / 비전 / 센서 설정'),
        const SizedBox(height: 12),
        TextFormField(
          controller: cameraTopicCtrl,
          enabled: isEditing,
          decoration: InputDecoration(
            labelText: '카메라 이미지 토픽 (RC_CAMERA_TOPIC)'.tr,
            hintText: '비워두면 로봇 프로필 기본값 사용 (예: /oakd/rgb/preview/image_raw)'.tr,
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: gripperCameraTopicCtrl,
          enabled: isEditing,
          decoration: InputDecoration(
            labelText: 'Stretch3 그리퍼 RGB 토픽 (RC_GRIPPER_CAMERA_TOPIC)'.tr,
            hintText: '예: /gripper_camera/color/image_rect_raw'.tr,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: gripperDepthTopicCtrl,
                enabled: isEditing,
                decoration: InputDecoration(
                  labelText: '그리퍼 Depth 토픽 (RC_GRIPPER_DEPTH_TOPIC)'.tr,
                  hintText: '/gripper_camera/aligned_depth_to_color/image_raw',
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: gripperCameraInfoTopicCtrl,
                enabled: isEditing,
                decoration: InputDecoration(
                  labelText: '그리퍼 CameraInfo (RC_GRIPPER_CAMERA_INFO_TOPIC)'.tr,
                  hintText:
                      '/gripper_camera/aligned_depth_to_color/camera_info',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: gripperPointcloudTopicCtrl,
          enabled: isEditing,
          decoration: InputDecoration(
            labelText: '그리퍼 PointCloud 토픽 (RC_GRIPPER_POINTCLOUD_TOPIC)'.tr,
            hintText: '예: /gripper_camera/depth/color/points'.tr,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Switch(
              value: useGripperVision,
              onChanged: isEditing ? onUseGripperVisionChanged : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text('그리퍼 카메라 ONNX 객체 인식 활성화 (RC_USE_GRIPPER_VISION)'.tr),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: gripperVisionMaxInferenceHzCtrl,
          enabled: isEditing,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText:
                '그리퍼 비전 최대 추론 Hz (RC_GRIPPER_VISION_MAX_INFERENCE_HZ)'.tr,
            hintText: '예: 5.0'.tr,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Switch(
              value: useVision,
              onChanged: isEditing ? onUseVisionChanged : null,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text('ONNX 객체 인식 비전 노드 활성화 (RC_USE_VISION)'.tr)),
          ],
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: visionModelPathCtrl,
          enabled: isEditing,
          decoration: InputDecoration(
            labelText: 'ONNX 모델 파일 경로 (RC_VISION_MODEL_PATH)'.tr,
            hintText:
                'use_vision=true 시 필수 (예: /ros2_ws/models/yolov8n.onnx)'.tr,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: lidarTopicCtrl,
                enabled: isEditing,
                decoration: InputDecoration(
                  labelText: '자가진단 라이다 토픽 (RC_LIDAR_TOPIC)'.tr,
                  hintText: '비워두면 robot_config 사용 (예: /scan)'.tr,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: imuTopicCtrl,
                enabled: isEditing,
                decoration: InputDecoration(
                  labelText: '자가진단 IMU 토픽 (RC_IMU_TOPIC)'.tr,
                  hintText: '비워두면 robot_config 사용 (예: /imu/data)'.tr,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
