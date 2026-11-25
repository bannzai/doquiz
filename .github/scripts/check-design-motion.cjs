// documents/design の資料のうち「もう一度動かす」(.replay) のボタンを持つページの動きを、ブラウザで確かめる。
// 静止画では分からない次の 4 つを確かめ、どれかが違えば exit 1 で終わる。
//   1. 開いた直後に動きが始まっていて、3.5 秒後には全部終わっている
//   2. 「もう一度動かす」を押すと、そのボタンの案の中だけで動きが始まり直す
//   3. 動きを減らす設定 (prefers-reduced-motion: reduce) では、開いた直後も押した後も動きが 1 つも無い
//   4. 動きの途中の見え方 (開いた直後と、押した直後) を画像に残す
// 使い方: node check-design-motion.cjs <ページの URL> <画像の出力先のディレクトリ> <画像の名前の先頭>
// 何回実行しても同じ結果になる (ページを読むだけで、画像は同じ名前で上書きする)。
const { chromium } = require('playwright');

const [url, outputDirectory, prefix] = process.argv.slice(2);
const viewport = { width: 1360, height: 900 };

/** scope (CSS セレクタ。無ければページ全体) の中で動いている最中のアニメーションの数を返す。 */
function runningAnimationCount(page, scope) {
  return page.evaluate(
    (selector) =>
      (selector ? document.querySelector(selector).getAnimations({ subtree: true }) : document.getAnimations()).filter(
        (animation) => animation.playState === 'running'
      ).length,
    scope
  );
}

/** condition が真なら message を OK として標準出力に出し、偽なら message を持つ Error を投げる。 */
function expect(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
  console.log(`OK: ${message}`);
}

(async () => {
  const browser = await chromium.launch();
  try {
    const page = await browser.newPage({ viewport });
    await page.goto(url);
    const planSelectors = await page.evaluate(() =>
      [...document.querySelectorAll('.replay')].map((replay) => `#${replay.closest('section').id}`)
    );
    expect(planSelectors.length > 0, `「もう一度動かす」のボタンがある (${planSelectors.length} 個)`);

    expect((await runningAnimationCount(page)) > 0, '開いた直後に動きが始まっている');
    await page.waitForTimeout(300);
    await page.screenshot({ path: `${outputDirectory}/${prefix}-motion-opened.png`, fullPage: true });
    await page.waitForTimeout(3200);
    expect((await runningAnimationCount(page)) === 0, '開いて 3.5 秒後には動きが全部終わっている');

    for (const planSelector of planSelectors) {
      await page.locator(`${planSelector} .replay`).click();
      expect((await runningAnimationCount(page, planSelector)) > 0, `${planSelector} の「もう一度動かす」を押すと動きが始まり直す`);
      expect((await runningAnimationCount(page)) === (await runningAnimationCount(page, planSelector)),`${planSelector} のボタンは ほかの案の動きを始めない`);
      await page.waitForTimeout(300);
      await page.locator(planSelector).screenshot({ path: `${outputDirectory}/${prefix}-motion-replayed-${planSelector.slice(1)}.png` });
      await page.waitForTimeout(3200);
    }

    const reducedMotionPage = await browser.newPage({ viewport, reducedMotion: 'reduce' });
    await reducedMotionPage.goto(url);
    expect((await runningAnimationCount(reducedMotionPage)) === 0, '動きを減らす設定では 開いた直後に動きが無い');
    await reducedMotionPage.locator(`${planSelectors[0]} .replay`).click();
    expect((await runningAnimationCount(reducedMotionPage)) === 0, '動きを減らす設定では 「もう一度動かす」を押しても動きが無い');
  } finally {
    await browser.close();
  }
})().catch((error) => {
  console.error(`NG: ${error.message}`);
  process.exit(1);
});
