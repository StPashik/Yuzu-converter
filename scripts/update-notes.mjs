// Sparkle renders Markdown natively; the same reviewed English file supplies GitHub and the signed feed.
export function releaseNotesDescription(markdown, version) {
  if (!/^\d+\.\d+\.\d+$/.test(version) ||
      !markdown.startsWith(`# Yuzu Converter ${version}\n`) ||
      !markdown.includes('\n## What changed\n') || Buffer.byteLength(markdown) > 256 * 1024) {
    throw new Error('Provide English release notes for this version with a What changed section.');
  }
  return `<description sparkle:format="markdown"><![CDATA[${markdown.replaceAll(']]>', ']]]]><![CDATA[>')}]]></description>`;
}
