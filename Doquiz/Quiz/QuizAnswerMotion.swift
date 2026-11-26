import SwiftUI

// 動きの値は、owner が選んだクイズの見た目の案 A (`documents/design/quiz-look-2026-11-25/index.html` の `.plan-a` と `@keyframes`) の値をそのまま使う
// (`documents/DIRECTION.md`「決めたこと」の 2026-11-26 の行)。

/// 問いに答えた瞬間に、選んだ選択肢・答えの入力欄・判定の面にかける動き。
nonisolated enum QuizAnswerMotion: Equatable {
    /// 合っている時の、小さく縮んでから弾んで元の大きさに戻る動き。紙吹雪も落とす。
    case pop
    /// 合っていない時の、小さく左右に揺れる動き。
    case shake
}

/// 答えた後にかける動きを返す。動きを減らす設定 (アクセシビリティの「視差効果を減らす」) が入っている時は、判定にかかわらず nil (動かさない)。
///
/// - Parameter isCorrect: 回答を合っていると判定したか
/// - Parameter reducesMotion: 動きを減らす設定が入っているか
nonisolated func quizAnswerMotion(isCorrect: Bool, reducesMotion: Bool) -> QuizAnswerMotion? {
    guard !reducesMotion else {
        return nil
    }
    return isCorrect ? .pop : .shake
}

/// 進み具合の線のうち、`segmentIndex` 番目の区切りの横の伸び (0 で無し、1 で伸びきった状態) を返す。
///
/// 今の問いの区切り (`currentIndex`) だけが、画面が出た後 (`hasGrown`) に 0 から伸びる。ほかの区切りと、動きを減らす設定が入っている時は伸びきった状態で出す。
nonisolated func quizProgressSegmentScale(segmentIndex: Int, currentIndex: Int, hasGrown: Bool, reducesMotion: Bool) -> CGFloat {
    segmentIndex == currentIndex && !hasGrown && !reducesMotion ? 0 : 1
}

/// 答えた瞬間の動きの途中の値。`keyframeAnimator` が時間に沿って変える。
nonisolated struct QuizAnswerMotionFrame {
    /// 大きさの倍率。
    var scale: CGFloat = 1
    /// 横にずらす量 (pt)。
    var offsetX: CGFloat = 0
}

/// `motion` の動きを 1 回だけかける。`motion` が nil の時は動かさない。
///
/// 答える前から画面にある選択肢と入力欄は、答えて `motion` が nil から変わった時に動く。
/// 答えた時に画面に足される判定の面は、出た時に動く (出た時点で `motion` が決まっていて、値が変わらないため)。
/// SwiftUI の `@State` を持つ必要があるため、関数ではなく `ViewModifier` にしている。
struct QuizAnswerMotionEffect: ViewModifier {
    /// かける動き。
    let motion: QuizAnswerMotion?
    /// この画面の部品が出たか。出る前は動きの始まりにしない。
    @State private var hasAppeared = false

    func body(content: Content) -> some View {
        content
            .keyframeAnimator(initialValue: QuizAnswerMotionFrame(), trigger: hasAppeared ? motion : nil) { content, frame in
                content
                    .scaleEffect(frame.scale)
                    .offset(x: frame.offsetX)
            } keyframes: { _ in
                KeyframeTrack(\.scale) {
                    // 案 A の `@keyframes pop` (0.92 倍から 1 倍) と、弾む曲線 `cubic-bezier(.2,1.6,.4,1)` を 0.45 秒 (判定の面の値) の弾むばねで写す。
                    MoveKeyframe(motion == .pop ? 0.92 : 1)
                    SpringKeyframe(1, duration: 0.45, spring: .bouncy)
                }
                KeyframeTrack(\.offsetX) {
                    // 案 A の `@keyframes shake` (0.4 秒で -6px・6px・0 に揺れる。25% と 75% の時点で端に来る)。
                    LinearKeyframe(motion == .shake ? -6 : 0, duration: 0.1)
                    LinearKeyframe(motion == .shake ? 6 : 0, duration: 0.2)
                    LinearKeyframe(0, duration: 0.1)
                }
            }
            .onAppear {
                hasAppeared = true
            }
    }
}

extension View {
    /// `motion` の動きを 1 回だけかける (`QuizAnswerMotionEffect`)。
    func quizAnswerMotionEffect(motion: QuizAnswerMotion?) -> some View {
        modifier(QuizAnswerMotionEffect(motion: motion))
    }
}

/// 紙吹雪の黄。案 A の紙吹雪の色 (`#F2B705`) のうち、アプリのほかの色に無いもの。紙吹雪にだけ使う。
let quizConfettiYellowColor = Color(red: 0xF2 / 255, green: 0xB7 / 255, blue: 0x05 / 255)

/// 合っている時に判定の面の上から落とす紙吹雪。出た時に 1 回だけ落ちて消える。
///
/// 押す操作を受けず、読み上げの対象にもしない (飾りのため)。
struct QuizConfetti: View {
    /// 紙吹雪 1 枚ずつの、横の位置 (面の幅に対する割合) と色。案 A の `.confetti:nth-child(1)` から `(7)` の `left` と `background`。
    private let pieces: [(horizontalRatio: CGFloat, color: Color)] = [
        (0.08, doquizAccentColor),
        (0.22, doquizCorrectColor),
        (0.36, quizConfettiYellowColor),
        (0.50, doquizCapturingColor),
        (0.64, doquizAccentColor),
        (0.78, doquizCorrectColor),
        (0.90, quizConfettiYellowColor),
    ]

    var body: some View {
        GeometryReader { geometryProxy in
            ForEach(Array(pieces.enumerated()), id: \.offset) { pieceIndex, piece in
                QuizConfettiPiece(
                    color: piece.color,
                    // 遅れは案 A の `.plan-a.play .confetti` と `.confetti:nth-child(even)` の `animation-delay`。pieceIndex は 0 から数えるため、偶数の pieceIndex が CSS の奇数番目に当たる。
                    delay: pieceIndex.isMultiple(of: 2) ? 0.25 : 0.45
                )
                .position(x: geometryProxy.size.width * piece.horizontalRatio, y: 0)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// 紙吹雪が落ち始める縦の位置 (pt)。案 A の `@keyframes fall` の始まり (`translateY(-12px)`)。
nonisolated private let quizConfettiStartOffsetY: CGFloat = -12
/// 紙吹雪が落ちきる縦の位置 (pt)。案 A の `@keyframes fall` の終わり (`translateY(150px)`)。
nonisolated private let quizConfettiEndOffsetY: CGFloat = 150
/// 紙吹雪が落ちるのにかかる秒数。案 A の `.plan-a.play .confetti` の `fall 1.4s ease-in`。
nonisolated private let quizConfettiFallDuration: TimeInterval = 1.4

/// 紙吹雪の 1 枚の、落ちる途中の値。
nonisolated struct QuizConfettiPieceFrame {
    /// 不透明度。落ち始める前は見えないように 0 から始める。
    var opacity: Double = 0
    /// 縦にずらす量 (pt)。落ち始める位置から始める。
    var offsetY: CGFloat = quizConfettiStartOffsetY
    /// 回った角度 (度)。回る前の 0 から始める。
    var rotationDegrees: Double = 0
}

/// 紙吹雪の 1 枚。出てから `delay` 秒待って、回りながら落ちて消える。
struct QuizConfettiPiece: View {
    /// 紙吹雪の色。
    let color: Color
    /// 出てから落ち始めるまでの秒数。
    let delay: TimeInterval
    /// この紙吹雪が出たか。出た時に 1 回だけ落とす。
    @State private var hasAppeared = false

    var body: some View {
        // 大きさと角の丸みは案 A の `.confetti` の値。
        RoundedRectangle(cornerRadius: 2)
            .fill(color)
            .frame(width: 8, height: 12)
            .keyframeAnimator(initialValue: QuizConfettiPieceFrame(), trigger: hasAppeared) { content, frame in
                content
                    .rotationEffect(.degrees(frame.rotationDegrees))
                    .offset(y: frame.offsetY)
                    .opacity(frame.opacity)
            } keyframes: { _ in
                // 終わりの不透明度と回転は案 A の `@keyframes fall` の値。
                KeyframeTrack(\.opacity) {
                    LinearKeyframe(0, duration: delay)
                    MoveKeyframe(1)
                    LinearKeyframe(0, duration: quizConfettiFallDuration, timingCurve: .easeIn)
                }
                KeyframeTrack(\.offsetY) {
                    LinearKeyframe(quizConfettiStartOffsetY, duration: delay)
                    LinearKeyframe(quizConfettiEndOffsetY, duration: quizConfettiFallDuration, timingCurve: .easeIn)
                }
                KeyframeTrack(\.rotationDegrees) {
                    LinearKeyframe(0, duration: delay)
                    LinearKeyframe(300, duration: quizConfettiFallDuration, timingCurve: .easeIn)
                }
            }
            .onAppear {
                hasAppeared = true
            }
    }
}
