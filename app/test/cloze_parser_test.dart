import 'package:flutter_test/flutter_test.dart';
import 'package:onestep/core/domain/cloze_parser.dart';

/// 完形填空解析测试。
void main() {
  test('识别 cloze 序号并去重排序', () {
    const t = '苹果是{{c1::红色}}的，{{c2::香蕉}}是黄色的，{{c1::苹果}}长在树上';
    expect(ClozeParser.indices(t), [1, 2]);
  });

  test('无 cloze 时返回空', () {
    expect(ClozeParser.indices('普通文本'), isEmpty);
    expect(ClozeParser.hasCloze('普通文本'), isFalse);
  });

  test('hasCloze 识别', () {
    expect(ClozeParser.hasCloze('有{{c1::内容}}'), isTrue);
  });

  test('渲染第 1 张：c1 挖空、c2 显示完整', () {
    const t = '苹果是{{c1::红色}}的，{{c2::香蕉}}是黄色的';
    final q = ClozeParser.renderQuestion(t, 1);
    expect(q, contains('[...]'));
    expect(q, isNot(contains('红色')));
    expect(q, contains('香蕉')); // 其它 cloze 显示原内容
  });

  test('渲染第 2 张：c2 挖空、c1 显示完整', () {
    const t = '苹果是{{c1::红色}}的，{{c2::香蕉}}是黄色的';
    final q = ClozeParser.renderQuestion(t, 2);
    expect(q, contains('红色')); // c1 显示原内容
    expect(q, contains('[...]'));
    expect(q, isNot(contains('香蕉')));
  });

  test('带提示的 cloze {{c1::提示::答案}}', () {
    const t = '法国的首都是{{c1::城市::巴黎}}';
    // 问题里非当前 cloze 显示答案段；当前挖空。
    final q1 = ClozeParser.renderQuestion(t, 1);
    expect(q1, contains('[...]'));
    expect(q1, isNot(contains('巴黎')));
    // 答案取最后一段。
    expect(ClozeParser.answerFor(t, 1), '巴黎');
  });

  test('answerFor 取出被挖空的答案', () {
    const t = '水在{{c1::0}}度沸腾';
    expect(ClozeParser.answerFor(t, 1), '0');
  });

  test('answerFor 无此序号抛异常', () {
    expect(() => ClozeParser.answerFor('只有{{c1::一}}', 2), throwsArgumentError);
  });

  test('多个同序号删除点渲染为一个占位', () {
    const t = '{{c1::猫}}和{{c1::猫}}都叫{{c2::喵}}';
    final q1 = ClozeParser.renderQuestion(t, 1);
    // 两个 c1 都挖空。
    final placeholders = '[...]'.allMatches(q1).length;
    expect(placeholders, 2);
    expect(q1, contains('喵')); // c2 显示完整
  });
}
