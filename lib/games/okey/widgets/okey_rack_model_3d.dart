import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';

/// عارض نموذج GLB ثلاثي الأبعاد للاستكانة — زاوية ثابتة أمامية
/// مائلة قليلاً من الأعلى، بدون تحكم باللمس حتى لا يتعارض مع سحب الأحجار
class OkeyRack3DModel extends StatelessWidget {
  final String modelPath;

  const OkeyRack3DModel({super.key, required this.modelPath});

  @override
  Widget build(BuildContext context) {
    // على الويب يعمل عبر عنصر <model-viewer> الحقيقي
    return ClipRRect(
      borderRadius: BorderRadius.circular(5),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ModelViewer(
            key: ValueKey(modelPath),
            src: modelPath,
            alt: '3D Okey rack',
            backgroundColor: Colors.transparent,
            cameraControls: false,
            autoRotate: false,
            autoPlay: false,
            disableZoom: true,
            disablePan: true,
            disableTap: true,
            interactionPrompt: InteractionPrompt.none,
            // أمامي مائل للأعلى قليلاً لإظهار عمق النموذج
            cameraOrbit: '0deg 68deg 105%',
            fieldOfView: '30deg',
            loading: Loading.eager,
            debugLogging: kDebugMode,
          ),
          // طبقة شفافة تمتص اللمسات حتى لا يبتلعها WebView
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () {},
            ),
          ),
        ],
      ),
    );
  }
}
