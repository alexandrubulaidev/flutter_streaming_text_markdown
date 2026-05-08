import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_streaming_text_markdown/src/utils/markdown_auto_close.dart';

/// Helper: simulates character-by-character streaming of [fullText] and
/// asserts that [autoCloseMarkdown] never produces raw marker characters
/// in positions where they would render literally.
void _assertStreamingProducesValidMarkdown(
  String fullText, {
  required bool Function(String rendered) isValid,
  String? description,
}) {
  for (int i = 1; i <= fullText.length; i++) {
    final partial = fullText.substring(0, i);
    final result = autoCloseMarkdown(partial);
    expect(
      isValid(result),
      isTrue,
      reason: '${description ?? fullText}: '
          'partial "$partial" → "$result" is not valid',
    );
  }
}

/// Returns true if the string does NOT contain raw unclosed bold/italic
/// markers (i.e. odd number of `**` or `*` that would render literally).
bool _hasNoRawMarkers(String text) {
  // Empty or whitespace-only is fine
  if (text.trim().isEmpty) return true;

  // Count ** (bold) markers — skip list markers (* at line start + space)
  int boldCount = 0;
  int italicCount = 0;
  for (int i = 0; i < text.length; i++) {
    if (text[i] == '*') {
      // Skip list markers
      if (i + 1 < text.length && text[i + 1] == ' ') {
        int j = i - 1;
        while (j >= 0 && text[j] == ' ') {
          j--;
        }
        if (j < 0 || text[j] == '\n') continue;
      }
      if (i + 1 < text.length && text[i + 1] == '*') {
        boldCount++;
        i++;
      } else {
        italicCount++;
      }
    }
  }
  return boldCount.isEven && italicCount.isEven;
}

void main() {
  group('autoCloseMarkdown', () {
    group('empty / plain text', () {
      test('empty string', () {
        expect(autoCloseMarkdown(''), '');
      });

      test('plain text without markers', () {
        expect(autoCloseMarkdown('hello world'), 'hello world');
      });
    });

    group('bold (**)', () {
      test('streaming **this is text** char by char never shows raw markers',
          () {
        _assertStreamingProducesValidMarkdown(
          '**this is text**',
          isValid: _hasNoRawMarkers,
          description: 'bold streaming',
        );
      });

      test('unclosed bold with content → auto-closed', () {
        expect(autoCloseMarkdown('**bold text'), '**bold text**');
      });

      test('complete bold → unchanged', () {
        expect(autoCloseMarkdown('**bold text**'), '**bold text**');
      });

      test('just ** → empty', () {
        expect(autoCloseMarkdown('**'), '');
      });

      test('text before unclosed bold', () {
        expect(autoCloseMarkdown('hello **world'), 'hello **world**');
      });

      test('bold with trailing space', () {
        expect(autoCloseMarkdown('**bold '), '**bold**');
      });

      test('partial closer **bold*', () {
        expect(autoCloseMarkdown('**bold*'), '**bold**');
      });
    });

    group('italic (*)', () {
      test('streaming *this is text* char by char never shows raw markers', () {
        _assertStreamingProducesValidMarkdown(
          '*this is text*',
          isValid: _hasNoRawMarkers,
          description: 'italic streaming',
        );
      });

      test('unclosed italic with content → auto-closed', () {
        expect(autoCloseMarkdown('*italic text'), '*italic text*');
      });

      test('complete italic → unchanged', () {
        expect(autoCloseMarkdown('*italic*'), '*italic*');
      });

      test('just * → empty', () {
        expect(autoCloseMarkdown('*'), '');
      });

      test('italic with trailing space', () {
        expect(autoCloseMarkdown('*italic '), '*italic*');
      });
    });

    group('list markers (* at line start)', () {
      test('bullet list item not treated as italic', () {
        expect(autoCloseMarkdown('* list item'), '* list item');
      });

      test('multiple bullet items', () {
        expect(
          autoCloseMarkdown('* item one\n* item two'),
          '* item one\n* item two',
        );
      });

      test('bullet list with bold inside', () {
        expect(
          autoCloseMarkdown('* item **bold'),
          '* item **bold**',
        );
      });

      test('indented bullet not treated as italic', () {
        expect(autoCloseMarkdown('  * indented item'), '  * indented item');
      });
    });

    group('strikethrough (~~)', () {
      test('unclosed strikethrough → auto-closed', () {
        expect(autoCloseMarkdown('~~strike text'), '~~strike text~~');
      });

      test('complete strikethrough → unchanged', () {
        expect(autoCloseMarkdown('~~strike~~'), '~~strike~~');
      });

      test('trailing ~ stripped', () {
        expect(autoCloseMarkdown('~~strike~'), '~~strike~~');
      });
    });

    group('inline code (`)', () {
      test('unclosed backtick → auto-closed', () {
        expect(autoCloseMarkdown('`code text'), '`code text`');
      });

      test('complete inline code → unchanged', () {
        expect(autoCloseMarkdown('`code`'), '`code`');
      });

      test('trailing backtick stripped', () {
        // `` → strip trailing ` → ` → backtickCount=1 → append ` → ``
        final result = autoCloseMarkdown('`code`');
        expect(result, '`code`');
      });
    });

    group('links', () {
      test('unclosed link paren → auto-closed', () {
        expect(
          autoCloseMarkdown('[Hotel Name](HOTELID'),
          '[Hotel Name](HOTELID)',
        );
      });

      test('complete link → unchanged', () {
        expect(
          autoCloseMarkdown('[Hotel Name](HOTELID)'),
          '[Hotel Name](HOTELID)',
        );
      });

      test('link with no url yet', () {
        expect(autoCloseMarkdown('[Hotel Name]('), '[Hotel Name]()');
      });
    });

    group('real-world hotel summary streaming', () {
      const fullText = '* Opt for a legendary luxury experience → '
          '[Athenee Palace Hilton Bucharest](HLBUH206)\n'
          '* Want a prime modern business stay → '
          '[JW Marriott Bucharest Grand Hotel](MCBUHROM)';

      test('streaming full hotel summary never shows raw markers', () {
        _assertStreamingProducesValidMarkdown(
          fullText,
          isValid: _hasNoRawMarkers,
          description: 'hotel summary streaming',
        );
      });
    });

    group('spaces and whitespace edge cases', () {
      test('bold with trailing space strips ws then auto-closes', () {
        expect(autoCloseMarkdown('**bold '), '**bold**');
      });

      test('bold with multiple trailing spaces', () {
        expect(autoCloseMarkdown('**bold   '), '**bold**');
      });

      test('italic with trailing space', () {
        expect(autoCloseMarkdown('*italic '), '*italic*');
      });

      test('bold text with internal spaces auto-closes correctly', () {
        expect(
          autoCloseMarkdown('**bold text here'),
          '**bold text here**',
        );
      });

      test('text before bold with trailing space', () {
        expect(autoCloseMarkdown('hello **world '), 'hello **world**');
      });

      test('streaming **50 EUR** char by char never shows raw markers', () {
        _assertStreamingProducesValidMarkdown(
          '**50 EUR**',
          isValid: _hasNoRawMarkers,
          description: 'bold with space streaming',
        );
      });

      test('streaming I suggest the **50 EUR** plan', () {
        _assertStreamingProducesValidMarkdown(
          'I suggest the **50 EUR** plan',
          isValid: _hasNoRawMarkers,
          description: 'bold in sentence streaming',
        );
      });

      test('streaming **bold** and *italic* together', () {
        _assertStreamingProducesValidMarkdown(
          '**bold** and *italic*',
          isValid: _hasNoRawMarkers,
          description: 'bold+italic streaming',
        );
      });

      test('streaming multiple bold phrases', () {
        _assertStreamingProducesValidMarkdown(
          'Try **Hotel A** or **Hotel B** for best value',
          isValid: _hasNoRawMarkers,
          description: 'multiple bold streaming',
        );
      });

      test('lone ** with trailing space → empty', () {
        expect(autoCloseMarkdown('** '), '');
      });

      test('lone * with trailing space → empty', () {
        expect(autoCloseMarkdown('* '), '');
      });

      test('bold after newline with trailing space', () {
        expect(
          autoCloseMarkdown('line one\n**bold '),
          'line one\n**bold**',
        );
      });
    });

    group('mixed content', () {
      test('bold and italic in same text', () {
        expect(
          autoCloseMarkdown('**bold** and *italic'),
          '**bold** and *italic*',
        );
      });

      test('complete bold + italic → unchanged', () {
        expect(
          autoCloseMarkdown('**bold** and *italic*'),
          '**bold** and *italic*',
        );
      });
    });
  });
}
