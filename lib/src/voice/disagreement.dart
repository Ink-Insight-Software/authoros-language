/// A character who can say "I don't think I would", and an author who decides.
///
/// Phase 3.7 asks that a character be able to disagree with what the author
/// proposes when it conflicts with their established goals, values, fears or
/// behaviour, that they can show supporting story evidence, that the author can
/// keep their plan, and that a disagreement can become a discovery or a
/// contradiction thread. It adds the line that governs the rest: *never present
/// character interpretation as higher authority than the author.*
///
/// ## What this file does and does not do
///
/// It **detects**, and it **records how the author resolved it**. It does not
/// decide. There is no resolution here in which the character overrules the
/// author: every [DisagreementResolution] is something the author did, or a way
/// the disagreement was kept for later. A test holds that list.
///
/// Detection is by the terms an author's proposal uses against the terms a
/// commitment avoids. It is a rule, not a reading: the proposal arrives as a
/// plain statement with its terms already pulled out (plan 2.9, which is the
/// language layer's job), and a commitment lists, in the author's own records,
/// what it stands against. Where those meet, the character has something to say,
/// and the commitment it came from is the evidence.
library;

/// What kind of thing a character holds to.
enum CommitmentKind { goal, value, fear, behaviour }

/// How firmly it is held.
enum CommitmentWeight {
  mild(0.3),
  strong(0.6),
  core(0.9);

  const CommitmentWeight(this.value);

  final double value;
}

/// Something the character holds to, drawn from the author's own records.
class CharacterCommitment {
  const CharacterCommitment({
    required this.id,
    required this.kind,
    required this.statement,
    this.avoids = const {},
    this.embraces = const {},
    this.weight = CommitmentWeight.strong,
  });

  final String id;
  final CommitmentKind kind;

  /// The commitment as the record states it. Quoted back as evidence.
  final String statement;

  /// Terms it stands against: "betray", "abandon", "lie".
  final Set<String> avoids;

  /// Terms it stands for. A proposal that uses these too is a more mixed case.
  final Set<String> embraces;

  final CommitmentWeight weight;
}

/// What the author has proposed, with its terms pulled out.
class AuthorProposal {
  const AuthorProposal({required this.text, required this.terms});

  /// The author's words, kept as they were said.
  final String text;

  /// The terms the proposal turns on. Supplied by whoever read the answer.
  final Set<String> terms;
}

/// A point at which the proposal runs against what the character holds to.
class Disagreement {
  const Disagreement({
    required this.commitment,
    required this.matchedTerms,
    required this.strength,
  });

  final CharacterCommitment commitment;
  final Set<String> matchedTerms;

  /// How strongly, zero to one.
  final double strength;

  /// The commitment as the record states it: what the character can point to.
  String get evidence => commitment.statement;
}

/// What became of a disagreement. Every value is the author's act, or a way of
/// keeping it open. None is the character prevailing.
enum DisagreementResolution {
  /// Not decided yet.
  open,

  /// The author kept their plan.
  authorKept,

  /// The author reconsidered, having heard the character.
  authorReconsidered,

  /// The author kept it as a thread to come back to.
  keptAsThread,

  /// The author made it a discovery: something to learn about the character.
  becameDiscovery,

  /// The author marked it a contradiction in the story to look at.
  becameContradiction,
}

/// A disagreement and how it ended, kept in the conversation's history.
class DisagreementRecord {
  const DisagreementRecord({
    required this.id,
    required this.commitmentId,
    required this.proposalText,
    required this.at,
    this.resolution = DisagreementResolution.open,
    this.sessionId,
  });

  final String id;
  final String commitmentId;
  final String proposalText;
  final DateTime at;
  final DisagreementResolution resolution;
  final String? sessionId;

  DisagreementRecord resolved(DisagreementResolution resolution) =>
      DisagreementRecord(
        id: id,
        commitmentId: commitmentId,
        proposalText: proposalText,
        at: at,
        resolution: resolution,
        sessionId: sessionId,
      );

  /// Whether the author has settled it.
  bool get isSettled => resolution != DisagreementResolution.open;
}

class DisagreementDetector {
  const DisagreementDetector({this.threshold = 0.25});

  /// The least strength worth speaking up about.
  final double threshold;

  /// The disagreements [proposal] raises against [commitments], strongest first.
  List<Disagreement> detect(
    AuthorProposal proposal,
    Iterable<CharacterCommitment> commitments,
  ) {
    final terms = {for (final t in proposal.terms) _normalise(t)}..remove('');
    final found = <Disagreement>[];
    for (final commitment in commitments) {
      final avoided = _matches(terms, commitment.avoids);
      if (avoided.isEmpty) continue;
      // One matching term is a hint, more is a pattern.
      var strength =
          commitment.weight.value *
          (0.5 + 0.25 * (avoided.length - 1)).clamp(0.0, 1.0);
      // It cuts both ways: the proposal also uses what they stand for.
      if (_matches(terms, commitment.embraces).isNotEmpty) strength *= 0.5;
      if (strength < threshold) continue;
      found.add(
        Disagreement(
          commitment: commitment,
          matchedTerms: avoided,
          strength: strength,
        ),
      );
    }
    found.sort((a, b) {
      final byStrength = b.strength.compareTo(a.strength);
      return byStrength != 0
          ? byStrength
          : a.commitment.id.compareTo(b.commitment.id);
    });
    return found;
  }

  Set<String> _matches(Set<String> proposal, Set<String> held) {
    final heldTerms = {for (final t in held) _normalise(t)}..remove('');
    final hits = <String>{};
    for (final p in proposal) {
      for (final h in heldTerms) {
        if (_same(p, h)) hits.add(p);
      }
    }
    return hits;
  }

  /// Equal, or one a stem of the other: "betray" meets "betrayal".
  static bool _same(String a, String b) {
    if (a == b) return true;
    final shorter = a.length < b.length ? a : b;
    final longer = a.length < b.length ? b : a;
    return shorter.length >= 4 && longer.startsWith(shorter);
  }

  static String _normalise(String term) => term.trim().toLowerCase();
}
