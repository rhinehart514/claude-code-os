#!/usr/bin/env python3
"""Generate LinkedIn PDF — honest version, real data, no borrowed credibility"""

from fpdf import FPDF
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import numpy as np
import tempfile, os

BG = '#0f0f0f'
GOLD = '#daa520'
RED_C = '#dc5050'
DIM_C = '#888888'
CARD_C = '#1c1c1c'
FG_C = '#e6e6e6'
GREEN_C = '#50c878'

W, H, MARGIN = 210, 297, 20
CW = W - 2 * MARGIN

FONT_PATH = '/System/Library/Fonts/Supplemental/Arial.ttf'
FONT_BOLD = '/System/Library/Fonts/Supplemental/Arial Bold.ttf'
FONT_ITALIC = '/System/Library/Fonts/Supplemental/Arial Italic.ttf'

class PDF(FPDF):
    def __init__(self):
        super().__init__()
        self.add_font('main', '', FONT_PATH)
        self.add_font('main', 'B', FONT_BOLD)
        self.add_font('main', 'I', FONT_ITALIC)

    def dark_page(self):
        self.add_page()
        self.set_fill_color(15, 15, 15)
        self.rect(0, 0, W, H, 'F')

    def big_title(self, text, size=30):
        self.set_font('main', 'B', size)
        self.set_text_color(230, 230, 230)
        self.multi_cell(CW, size * 0.48, text, align='L')

    def slide_title(self, text, size=18):
        self.set_font('main', 'B', size)
        self.set_text_color(218, 165, 32)
        self.multi_cell(CW, size * 0.55, text, align='L')
        self.ln(2)

    def caption(self, text, size=11):
        self.set_font('main', '', size)
        self.set_text_color(200, 200, 200)
        self.multi_cell(CW, size * 0.55, text, align='L')
        self.ln(3)

    def caveat(self, text, size=9):
        self.set_font('main', 'I', size)
        self.set_text_color(220, 80, 80)
        self.multi_cell(CW, size * 0.5, text, align='L')
        self.ln(2)

    def dim(self, text, size=10):
        self.set_font('main', '', size)
        self.set_text_color(120, 120, 120)
        self.multi_cell(CW, size * 0.5, text, align='L')


def fig_to_path(fig, name):
    path = os.path.join(tempfile.gettempdir(), f'{name}.png')
    fig.savefig(path, dpi=220, facecolor=BG, bbox_inches='tight')
    plt.close(fig)
    return path


def style_ax(ax, bg=None):
    ax.set_facecolor(bg or BG)
    for s in ['top','right']: ax.spines[s].set_visible(False)
    for s in ['left','bottom']: ax.spines[s].set_color('#333')
    ax.tick_params(colors=DIM_C, labelsize=8)


def chart_overview():
    """What the system measures and how"""
    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(7, 3))
    fig.patch.set_facecolor(BG)

    # Left: structural score over time (real project data pattern)
    style_ax(ax1, CARD_C)
    runs = list(range(1, 24))
    build =     [90,90,90,90,90,70,90,90,70,90,90,90,90,90,100,100,70,70,90,70,70,90,90]
    structure = [86,86,86,86,86,86,86,86,86,86,86,86,86,84,84,84,84,84,84,84,84,84,84]

    ax1.plot(runs, build, color=GREEN_C, linewidth=1.5, alpha=0.6, label='build')
    ax1.plot(runs, structure, color=GOLD, linewidth=2, label='structure')
    ax1.set_ylim(50, 110)
    ax1.set_title('Structural (every commit)', color=GREEN_C, fontsize=10, fontweight='bold')
    ax1.set_xlabel('score run', color=DIM_C, fontsize=8)
    ax1.legend(fontsize=7, framealpha=0.3, labelcolor=[GREEN_C, GOLD],
               facecolor=CARD_C, edgecolor='#333', loc='lower left')
    ax1.grid(axis='y', color='#222', linewidth=0.5)

    # Right: taste dimensions (real project taste data)
    style_ax(ax2, CARD_C)
    dims = ['hierarchy', 'whitespace', 'contrast', 'polish', 'emotion', 'density', 'wayfinding', 'distinct.', 'scroll']
    scores = [1, 1, 1, 1, 1, 1, 1, 1, 1]  # Real: both projects scored 1/5
    colors = [RED_C] * 9
    ax2.barh(dims, scores, color=colors, height=0.6)
    ax2.set_xlim(0, 5)
    ax2.set_title('Visual (on demand)', color=RED_C, fontsize=10, fontweight='bold')
    ax2.set_xlabel('score (1-5)', color=DIM_C, fontsize=8)
    ax2.axvline(x=2.5, color='#444', linestyle='--', linewidth=1)
    ax2.text(3, 0, 'passing', color='#444', fontsize=7, va='center')
    ax2.invert_yaxis()

    plt.tight_layout(w_pad=3)
    return fig_to_path(fig, 'overview')


def chart_ceiling_real():
    """Real ceiling dimension movement across evals"""
    fig, ax = plt.subplots(figsize=(7, 3.5))
    fig.patch.set_facecolor(BG)
    style_ax(ax)

    evals = ['Product\nEval', 'Return\nLoop', 'Taste +\nHygiene', 'Wiring\nSprint']
    x = np.arange(len(evals))

    escape_vel = [0.30, 0.35, 0.30, 0.40]
    return_pull = [0.20, 0.55, 0.55, 0.63]
    ia_benefit  = [0.65, 0.65, 0.65, 0.70]

    ax.plot(x, escape_vel, 'o-', color=RED_C, linewidth=2, markersize=8, label='escape velocity', zorder=3)
    ax.plot(x, return_pull, 's-', color=GOLD, linewidth=2, markersize=8, label='return pull', zorder=3)
    ax.plot(x, ia_benefit, '^-', color=GREEN_C, linewidth=2, markersize=8, label='IA benefit', zorder=3)

    ax.fill_between(x, escape_vel, alpha=0.1, color=RED_C)

    ax.set_xticks(x)
    ax.set_xticklabels(evals, fontsize=9, color=DIM_C)
    ax.set_ylim(0, 0.85)
    ax.set_ylabel('ceiling score', color=DIM_C, fontsize=9)
    ax.legend(fontsize=8, loc='upper left', framealpha=0.3,
              labelcolor=FG_C, facecolor=CARD_C, edgecolor='#333')
    ax.grid(axis='y', color='#1a1a1a', linewidth=0.5)

    # Annotate the regression
    ax.annotate('regressed', xy=(2, 0.30), xytext=(2.3, 0.18),
                color=RED_C, fontsize=8, fontweight='bold',
                arrowprops=dict(arrowstyle='->', color=RED_C, lw=1))

    return fig_to_path(fig, 'ceiling_real')


def chart_identity():
    """Real identity sprint data"""
    fig, ax = plt.subplots(figsize=(7, 3))
    fig.patch.set_facecolor(BG)
    style_ax(ax)

    scores = [0.30, 0.32, 0.35, 0.37, 0.39, 0.42, 0.44, 0.43,
              0.46, 0.50, 0.52, 0.54, 0.56, 0.58, 0.60, 0.62, 0.63]
    status = ['k','k','k','k','k','k','k','d',
              'k','k','k','k','k','k','k','k','k']

    best = [scores[0]]
    for s, st in zip(scores[1:], status[1:]):
        best.append(max(best[-1], s) if st == 'k' else best[-1])

    exps = range(len(scores))
    ax.plot(exps, best, color=GOLD, linewidth=2.5, zorder=3)

    for i, (s, st) in enumerate(zip(scores, status)):
        if st == 'k':
            ax.scatter(i, s, color=GREEN_C, s=40, zorder=4, edgecolors='none')
        else:
            ax.scatter(i, s, color=RED_C, s=60, zorder=4, marker='x', linewidths=2.5)

    ax.axvspan(-0.5, 7.5, alpha=0.05, color=GOLD)
    ax.axvspan(7.5, 16.5, alpha=0.05, color=GREEN_C)
    ax.text(3.5, 0.27, 'copy + voice', ha='center', color=GOLD, fontsize=8, alpha=0.7)
    ax.text(12, 0.27, 'visual identity', ha='center', color=GREEN_C, fontsize=8, alpha=0.7)

    ax.set_ylim(0.24, 0.70)
    ax.set_ylabel('identity score', color=DIM_C, fontsize=9)
    ax.set_xlabel('experiment', color=DIM_C, fontsize=9)
    ax.grid(axis='y', color='#1a1a1a', linewidth=0.5)

    ax.text(16.5, 0.635, '0.63', color=GOLD, fontsize=10, fontweight='bold')
    ax.text(0, 0.305, '0.30', color=DIM_C, fontsize=10)

    return fig_to_path(fig, 'identity')


def chart_discard_honest():
    """The discard rate problem -- front and center"""
    fig, ax = plt.subplots(figsize=(7, 3))
    fig.patch.set_facecolor(BG)
    style_ax(ax, CARD_C)

    categories = ['Actual rate\n(this system)', 'System\nwarning threshold', 'autoresearch\n(Karpathy)', 'Target for\nmeaningful R&D']
    rates = [4.6, 12, 50, 40]
    colors = [RED_C, GOLD, GREEN_C, GREEN_C]

    bars = ax.bar(categories, rates, color=colors, width=0.5, zorder=3)
    for bar, val in zip(bars, rates):
        ax.text(bar.get_x() + bar.get_width()/2, bar.get_height() + 1,
                f'{val}%', ha='center', color=FG_C, fontsize=11, fontweight='bold')

    ax.set_ylabel('discard rate %', color=DIM_C, fontsize=9)
    ax.set_ylim(0, 65)
    ax.grid(axis='y', color='#222', linewidth=0.5)

    return fig_to_path(fig, 'discard')


def chart_gap_feed_forward():
    """Real gap persistence from eval history"""
    fig, ax = plt.subplots(figsize=(7, 3.2))
    fig.patch.set_facecolor(BG)
    style_ax(ax)

    gaps = ['escape velocity', 'return pull', 'identity', 'distribution', 'visual personality']
    evals = ['Product\nEval', 'Return\nLoop', 'Taste +\nHygiene', 'Wiring\nSprint']

    data = {
        'escape velocity':    [1, 1, 1, 0.5],
        'return pull':        [1, 0.5, 0.5, 0.5],
        'identity':           [1, 0.5, 0, 0],
        'distribution':       [1, 0.5, 0, 0],
        'visual personality': [0, 0, 1, 0.5],
    }

    for yi, gap in enumerate(gaps):
        vals = data[gap]
        for xi, val in enumerate(vals):
            if val == 1:
                ax.scatter(xi, yi, s=250, color=RED_C, marker='s', zorder=3)
            elif val == 0.5:
                ax.scatter(xi, yi, s=250, color=GOLD, marker='s', zorder=3, alpha=0.7)
            else:
                ax.scatter(xi, yi, s=250, color=GREEN_C, marker='s', zorder=3, alpha=0.4)

    ax.set_xticks(range(len(evals)))
    ax.set_xticklabels(evals, color=DIM_C, fontsize=9)
    ax.set_yticks(range(len(gaps)))
    ax.set_yticklabels(gaps, color=FG_C, fontsize=10)
    ax.set_xlim(-0.5, len(evals) - 0.5)

    ax.scatter([], [], s=120, color=RED_C, marker='s', label='open')
    ax.scatter([], [], s=120, color=GOLD, marker='s', label='improving')
    ax.scatter([], [], s=120, color=GREEN_C, marker='s', alpha=0.4, label='resolved')
    ax.legend(fontsize=8, loc='lower right', framealpha=0.3,
              labelcolor=FG_C, facecolor=CARD_C, edgecolor='#333')
    ax.grid(axis='x', color='#1a1a1a', linewidth=0.5)

    return fig_to_path(fig, 'gaps')


def chart_self_audit():
    """The self-audit: before/after with context"""
    fig, ax = plt.subplots(figsize=(7, 3))
    fig.patch.set_facecolor(BG)
    style_ax(ax, CARD_C)

    dims = ['build', 'structure', 'hygiene']
    before = [100, 50, 50]
    after = [100, 70, 70]
    x = np.arange(len(dims))
    w = 0.3

    ax.bar(x - w/2, before, w, color=DIM_C, label='before (hardcoded fallback)', zorder=3)
    ax.bar(x + w/2, after, w, color=GOLD, label='after (real scoring)', zorder=3)

    ax.set_xticks(x)
    ax.set_xticklabels(dims, fontsize=10, color=DIM_C)
    ax.set_ylim(0, 115)
    ax.set_ylabel('score', color=DIM_C, fontsize=9)
    ax.legend(fontsize=8, loc='upper right', framealpha=0.3,
              labelcolor=FG_C, facecolor=CARD_C, edgecolor='#333')
    ax.grid(axis='y', color='#222', linewidth=0.5)

    # 200+ runs annotation
    ax.text(1, 55, '200+ runs of\nfake data', color=RED_C, fontsize=9,
            ha='center', fontweight='bold')

    return fig_to_path(fig, 'self_audit')


def chart_tests():
    """141/143 test suite"""
    fig, ax = plt.subplots(figsize=(7, 2.5))
    fig.patch.set_facecolor(BG)
    style_ax(ax)

    tiers = ['Deterministic\n(61)', 'Functional\n(35)', 'Canary\n(20)', 'Capability\n(20)', 'Autonomy\n(12)']
    passed = [61, 35, 20, 19, 11]
    total = [61, 35, 20, 20, 12]
    pcts = [p/t * 100 for p, t in zip(passed, total)]

    bars = ax.bar(tiers, pcts, color=GOLD, width=0.55, zorder=3)
    for bar, pct in zip(bars, pcts):
        if pct < 100:
            bar.set_color(RED_C)
            bar.set_alpha(0.8)

    for bar, p, t in zip(bars, passed, total):
        ax.text(bar.get_x() + bar.get_width()/2, bar.get_height() + 1,
                f'{p}/{t}', ha='center', va='bottom', color=FG_C,
                fontsize=11, fontweight='bold')

    ax.set_ylim(0, 115)
    ax.axhline(y=100, color='#333', linestyle='--', linewidth=1)
    ax.set_ylabel('pass rate %', color=DIM_C, fontsize=9)
    ax.grid(axis='y', color='#1a1a1a', linewidth=0.5)

    return fig_to_path(fig, 'tests')


def build_pdf():
    pdf = PDF()
    pdf.set_auto_page_break(auto=True, margin=20)

    overview = chart_overview()
    ceiling = chart_ceiling_real()
    identity = chart_identity()
    discard = chart_discard_honest()
    gaps = chart_gap_feed_forward()
    self_audit = chart_self_audit()
    tests = chart_tests()

    # --- 1: Title ---
    pdf.dark_page()
    pdf.set_xy(MARGIN, 50)
    pdf.big_title('Automated evaluation\nloops for product\ndevelopment', 30)
    pdf.ln(8)
    pdf.set_x(MARGIN)
    pdf.caption('65 experiments. 2 projects. 2 days.\nReal data, including the parts that don\'t work yet.', 14)
    pdf.ln(12)
    pdf.set_x(MARGIN)
    pdf.dim('March 2026', 12)

    # --- 2: What it measures ---
    pdf.dark_page()
    pdf.set_xy(MARGIN, 22)
    pdf.slide_title('Two tiers: structural checks vs visual evaluation')
    pdf.caption('Structural scoring (left) runs on every commit. Grep-based, fast, repeatable. Visual evaluation (right) takes Playwright screenshots and scores 9 taste dimensions via Claude vision. Both projects passed structural checks. Both scored 1/5 on taste -- routes were broken in production. That divergence is the entire point of running both.')
    pdf.image(overview, x=MARGIN, w=CW)
    pdf.ln(2)
    pdf.caveat('Caveat: taste score of 1/5 reflects deployment failures (404s), not design quality. This is a smoke test result, not a taste evaluation. The system caught it, but calling it "taste" overstates what was measured.')

    # --- 3: Ceiling dimensions ---
    pdf.dark_page()
    pdf.set_xy(MARGIN, 22)
    pdf.slide_title('Ceiling scores across 4 evaluation cycles')
    pdf.caption('Return pull (0.20 to 0.63) improved significantly after targeted sprint work. Escape velocity is stubborn -- improved, regressed, then partially recovered. These ceiling scores are self-assessed benchmarks, not externally validated.')
    pdf.image(ceiling, x=MARGIN, w=CW)
    pdf.ln(2)
    pdf.caveat('Caveat: these scores come from the system\'s own evaluation rubric. There is no external ground truth. The trend direction is more meaningful than the absolute numbers.')

    # --- 4: Identity sprint ---
    pdf.dark_page()
    pdf.set_xy(MARGIN, 22)
    pdf.slide_title('17 experiments, 1 discarded')
    pdf.caption('Identity score went from 0.30 to 0.63 in one sprint. Copy and voice changes (Phase 1) plateaued around 0.44. Visual identity changes (Phase 2) pushed further. The one discard was a gold ping animation that improved the score but violated the product\'s constraint set.')
    pdf.image(identity, x=MARGIN, w=CW)

    # --- 5: Discard rate ---
    pdf.dark_page()
    pdf.set_xy(MARGIN, 22)
    pdf.slide_title('The discard rate is too low')
    pdf.caption('3 discards out of 65 experiments. 4.6%. For comparison, Karpathy\'s autoresearch discards roughly half of its runs. A low discard rate means the agent is making safe, incremental changes -- not testing real hypotheses. The system correctly flags this. Fixing it requires pushing the agent toward riskier experiments.')
    pdf.image(discard, x=MARGIN, w=CW)
    pdf.ln(2)
    pdf.caveat('This is the most important slide. An experiment loop that rarely fails isn\'t experimenting -- it\'s committing.')

    # --- 6: Gap feed-forward ---
    pdf.dark_page()
    pdf.set_xy(MARGIN, 22)
    pdf.slide_title('Unresolved gaps persist until addressed')
    pdf.caption('Each row is a problem surfaced by an evaluation. Red squares persist across cycles. Escape velocity has been flagged since eval 1 and remains partially open. Identity was resolved after a dedicated sprint. New problems emerge as old ones close. The mechanism is simple -- append-only gap tracking -- but it prevents backlog amnesia.')
    pdf.image(gaps, x=MARGIN, w=CW)

    # --- 7: Self-audit ---
    pdf.dark_page()
    pdf.set_xy(MARGIN, 22)
    pdf.slide_title('The system scored itself and found bugs')
    pdf.caption('The scoring tool returned hardcoded 50/100 for 200+ runs because it didn\'t recognize CLI projects as scorable. The plateau detector was correctly flagging this the entire time. The warning existed. Nobody acted on it.')
    pdf.image(self_audit, x=MARGIN, w=CW)
    pdf.ln(2)
    pdf.caveat('This is both the best and worst finding. Best: the system can catch its own failures. Worst: 200+ runs of decorative data means every prior conclusion drawn from those scores was unfounded.')

    # --- 8: Test suite ---
    pdf.dark_page()
    pdf.set_xy(MARGIN, 22)
    pdf.slide_title('141 / 143 self-eval tests')
    pdf.caption('Five tiers of deterministic checks. No LLM-as-judge. The 2 failures: keep rate too high (slide 5) and taste score below MVP floor. The test suite warns at 100% pass rate because tests that always pass aren\'t testing anything.')
    pdf.image(tests, x=MARGIN, w=CW)
    pdf.ln(4)
    pdf.set_x(MARGIN)
    pdf.dim('All data from internal benchmarks. No external validation. N=2 projects, N=65 experiments, N=2 days. Interpret accordingly.', 9)

    out = os.path.join(os.path.dirname(__file__), 'autonomous-scoring-loops.pdf')
    pdf.output(out)
    print(f'PDF saved to: {out}')

if __name__ == '__main__':
    build_pdf()
