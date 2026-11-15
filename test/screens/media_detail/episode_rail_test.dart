import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plezy/screens/media_detail/episode_rail.dart';

void main() {
  testWidgets('continuous episode rail follows both directions, group jumps and season resets', (tester) async {
    for (final total in [23, 27, 30, 12]) {
      final lastGroup = groupForEpisodeIndex(total - 1);
      expect(episodeGroupLabel(lastGroup, total), '${lastGroup * 10 + 1}–$total');
    }
    var resetToken = 0;
    var position = 0;
    var episodeCount = 27;
    var railWidth = 390.0;
    var hasTail = false;
    var loadRequests = 0;
    late StateSetter update;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return Scaffold(
                body: Align(
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    width: railWidth,
                    child: DetailEpisodeRail(
                      episodeCount: episodeCount,
                      height: 158,
                      resetToken: resetToken,
                      initialIndex: position,
                      hasTail: hasTail,
                      canLoadMore: hasTail,
                      onLoadMore: () => loadRequests++,
                      onPositionChanged: (index) => position = index,
                      itemBuilder: (context, index) => Text('Episode ${index + 1}'),
                      groupsBuilder: (context, group, scrollToGroup) => Row(
                        children: [
                          Text('Group $group'),
                          for (var index = 0; index < (episodeCount + 9) ~/ 10; index++)
                            TextButton(
                              onPressed: () => scrollToGroup(index),
                              child: Text(episodeGroupLabel(index, episodeCount)),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
    final rail = find.byKey(const ValueKey('detail_episode_rail_scroll'));
    await tester.timedDrag(rail, const Offset(-2140, 0), const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.text('Group 1'), findsOneWidget);
    expect(position, greaterThanOrEqualTo(10));
    await tester.timedDrag(rail, const Offset(2140, 0), const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.text('Group 0'), findsOneWidget);
    await tester.tap(find.text('21–27'));
    await tester.pumpAndSettle();
    expect(position, 20);
    expect(find.text('Group 2'), findsOneWidget);
    update(() => resetToken++);
    await tester.pumpAndSettle();
    expect(position, 0);
    expect(find.text('Group 0'), findsOneWidget);
    update(() {
      episodeCount = 12;
      railWidth = 560;
      resetToken++;
    });
    await tester.pumpAndSettle();
    await tester.tap(find.text('11–12'));
    await tester.pumpAndSettle();
    expect(position, 10);
    expect(find.text('Group 1'), findsOneWidget);
    final controller = tester.widget<ListView>(rail).controller!;
    expect(controller.offset, 2140);
    controller.jumpTo(2193.5);
    update(() {});
    await tester.pumpAndSettle();
    expect(controller.offset, 2193.5);
    update(() {
      episodeCount = 20;
      railWidth = 720;
      hasTail = true;
      resetToken++;
    });
    await tester.pumpAndSettle();
    expect(loadRequests, 0);
    controller.jumpTo(3600);
    expect(loadRequests, 1);
    expect(tester.takeException(), isNull);
  });
}
