import 'dart:ui';

import 'package:capy_vocab/core/services/gemini_vision_service.dart';

const task13bJacketCanvasSize = Size(400, 800);

/// Approximation of the original five-object photo layout, expressed directly
/// as fractions of the 400x800 solver canvas.
///
/// Input identity is intentional: wardrobe, curtain, fan, box, jacket.
const task13bJacketWords = [
  VocabDetection(
    number: 1,
    word: 'wardrobe',
    phonetic: '/wardrobe/',
    meaning: 'tu quan ao',
    x: 0.373,
    y: 0.291,
    w: 0.384,
    h: 0.586,
  ),
  VocabDetection(
    number: 2,
    word: 'curtain',
    phonetic: '/curtain/',
    meaning: 'rem cua',
    x: 0.044,
    y: 0.078,
    w: 0.273,
    h: 0.688,
  ),
  VocabDetection(
    number: 3,
    word: 'fan',
    phonetic: '/fan/',
    meaning: 'quat',
    x: 0.147,
    y: 0.463,
    w: 0.293,
    h: 0.190,
  ),
  VocabDetection(
    number: 4,
    word: 'box',
    phonetic: '/box/',
    meaning: 'hop',
    x: 0.393,
    y: 0.792,
    w: 0.170,
    h: 0.086,
  ),
  VocabDetection(
    number: 5,
    word: 'jacket',
    phonetic: '/jacket/',
    meaning: 'ao khoac',
    x: 0.588,
    y: 0.288,
    w: 0.159,
    h: 0.146,
  ),
];

const task13bJacketNormalizedBoxes = [
  Rect.fromLTWH(0.373, 0.291, 0.384, 0.586),
  Rect.fromLTWH(0.044, 0.078, 0.273, 0.688),
  Rect.fromLTWH(0.147, 0.463, 0.293, 0.190),
  Rect.fromLTWH(0.393, 0.792, 0.170, 0.086),
  Rect.fromLTWH(0.588, 0.288, 0.159, 0.146),
];
