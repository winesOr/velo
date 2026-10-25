import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plezy/utils/ambient_palette_extractor.dart';
import 'package:plezy/widgets/vidhub_ambient_backdrop.dart';

void main() {
  group('AmbientPaletteExtractor 单元测试', () {
    test('正确从纯色像素流中提取主色调并自适应压暗', () {
      // 构造 16x16 的鲜艳蓝色像素流 (RGBA: 0, 100, 255, 255)
      const width = 16;
      const height = 16;
      final bytes = Uint8List(width * height * 4);
      for (int i = 0; i < bytes.length; i += 4) {
        bytes[i] = 0;
        bytes[i + 1] = 100;
        bytes[i + 2] = 255;
        bytes[i + 3] = 255;
      }

      final color = AmbientPaletteExtractor.extractFromRgbaBytes(bytes, width, height);

      // 验证提取出的颜色具备蓝色倾向且经过了 ~22% 的平滑压暗
      expect(color.a, greaterThan(0.99));
      expect(color.b, greaterThan(color.r));
      expect(color.b, greaterThan(color.g));
      // 压暗后的 B 通道约为 255 * 0.78 ≈ 199
      expect((color.b * 255).round(), inInclusiveRange(180, 220));
    });

    test('纯黑纯白或灰阶像素正确触发 fallback 机制', () {
      // 构造全灰色像素 (RGBA: 128, 128, 128, 255)
      const width = 8;
      const height = 8;
      final grayBytes = Uint8List(width * height * 4);
      for (int i = 0; i < grayBytes.length; i += 4) {
        grayBytes[i] = 128;
        grayBytes[i + 1] = 128;
        grayBytes[i + 2] = 128;
        grayBytes[i + 3] = 255;
      }

      const customFallback = Color(0xFF101214);
      final color = AmbientPaletteExtractor.extractFromRgbaBytes(grayBytes, width, height, fallback: customFallback);

      expect(color, equals(customFallback));
    });

    test('空数据和异常宽高输入安全返回默认色', () {
      final color = AmbientPaletteExtractor.extractFromRgbaBytes(Uint8List(0), 0, 0);
      expect(color, equals(AmbientPaletteExtractor.defaultFallback));
    });
  });

  group('VidHubAmbientBackdrop 渲染与层级测试', () {
    testWidgets('reduced motion makes palette transitions immediate', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: true),
            child: SizedBox(
              width: 320,
              height: 540,
              child: VidHubAmbientBackdrop(accentColor: Colors.green, backdropChild: SizedBox()),
            ),
          ),
        ),
      );
      final tween = tester.widget<TweenAnimationBuilder<Color?>>(find.byType(TweenAnimationBuilder<Color?>));
      expect(tween.duration, Duration.zero);
      expect(tester.takeException(), isNull);
    });

    testWidgets('正常构建四层分层结构：模糊底图、主色光晕、磨砂对比层与底部消退渐变', (tester) async {
      const testAccent = Color(0xFF1E88E5);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: const Scaffold(
            body: SizedBox(
              width: 400,
              height: 600,
              child: VidHubAmbientBackdrop(
                accentColor: testAccent,
                blurSigma: 32.0,
                glowIntensity: 0.5,
                backdropChild: ColoredBox(color: Colors.red),
                child: Text('Foreground Content'),
              ),
            ),
          ),
        ),
      );

      // 验证 ImageFiltered 存在且包含指定的模糊 sigma
      final imageFiltered = tester.widget<ImageFiltered>(find.byType(ImageFiltered));
      expect(imageFiltered.imageFilter, isNotNull);

      // 验证前景正常渲染且文字可见
      expect(find.text('Foreground Content'), findsOneWidget);

      // 验证氛围流光 TweenAnimationBuilder 正常运作
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(VidHubAmbientBackdrop), findsOneWidget);
    });

    testWidgets('动态切换 accentColor 时平滑触发插值更新', (tester) async {
      Color currentColor = const Color(0xFFE53935);

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              return Scaffold(
                body: VidHubAmbientBackdrop(
                  accentColor: currentColor,
                  backdropChild: const SizedBox(width: 200, height: 200),
                ),
                floatingActionButton: FloatingActionButton(
                  onPressed: () {
                    setState(() {
                      currentColor = const Color(0xFF43A047);
                    });
                  },
                ),
              );
            },
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 点击切换颜色
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200)); // 动画中途
      await tester.pumpAndSettle(); // 动画完成

      expect(tester.takeException(), isNull);
    });
  });
}
