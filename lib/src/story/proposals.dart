/// Opt-in proposal mode: when the story is silent, offer ideas, clearly labelled, and
/// write nothing until the author approves.
///
/// Three rules keep it honest:
///  * a proposal is not a fact: it lives in a [ProposalLedger], never in the index, so
///    retrieval can never answer from one;
///  * a proposal must cite the story facts that inspired it and must not contradict
///    anything the story states ([ProposalGuard]);
///  * approval is an explicit call by the author's action; it returns the text and its
///    grounding for the existing canon path to save (Companion saves a copy).
library;

import 'answer.dart';
import 'facts.dart';
import 'index.dart';
import 'labels.dart';
import 'question.dart';

class Proposal {
  const Proposal({
    required this.id,
    required this.text,
    required this.question,
    required this.grounding,
    required this.rationale,
  });

  final String id;

  /// The idea, worded as an idea ("Maybe ...").
  final String text;
  final String question;

  /// The exact words in the story that inspired it.
  final List<EvidenceRef> grounding;
  final String rationale;

  /// Always PROPOSED. Part of the type so no UI can show one unlabelled.
  EvidenceStatus get status => EvidenceStatus.proposed;
}

/// Makes proposals for an UNKNOWN answer. A creative generator (including a model) can
/// implement this; the guard applies to whatever it returns.
abstract class ProposalGenerator {
  List<Proposal> propose(Answer unknown, StoryIndex index);
}

/// Proposes only from what the story already contains: for a missing place it offers
/// places the story already names; it never invents a new one.
class GroundedProposalGenerator implements ProposalGenerator {
  const GroundedProposalGenerator({this.max = 3});
  final int max;

  @override
  List<Proposal> propose(Answer unknown, StoryIndex index) {
    if (unknown.status != EvidenceStatus.unknown || !unknown.offerProposal) {
      return const [];
    }
    final q = unknown.question;
    if (q.intent != QuestionIntent.location || q.entities.isEmpty) {
      return const [];
    }
    final thing = q.entities.first;
    // Places the story names, most recently mentioned first.
    final seen = <String>{};
    final places = <SlotValue>[];
    final byPlace = <String, Fact>{};
    for (final f in index.facts.reversed) {
      for (final slot in [f.location, f.destination, f.origin]) {
        final id = slot?.entityId;
        if (slot != null &&
            id != null &&
            id.startsWith('place_') &&
            seen.add(id)) {
          places.add(slot);
          byPlace[id] = f;
        }
      }
    }
    final out = <Proposal>[];
    for (final p in places.take(max)) {
      final fact = byPlace[p.entityId]!;
      final src = index.source(fact.sourceId)!;
      out.add(
        Proposal(
          id: 'p_${thing}_${p.entityId}',
          text:
              'Maybe it is ${p.text.replaceFirst(RegExp(r'^(to|from|into|onto)\s+'), 'in ')}.',
          question: q.text,
          grounding: [
            EvidenceRef(
              sourceId: fact.sourceId,
              start: fact.sentenceStart,
              end: fact.sentenceEnd,
              quote: src.text.substring(fact.sentenceStart, fact.sentenceEnd),
            ),
          ],
          rationale: 'The story already names ${p.text.split(' ').last}.',
        ),
      );
    }
    return out;
  }
}

/// Rejects a proposal that cites nothing, or that the story contradicts.
class ProposalGuard {
  const ProposalGuard();

  /// Returns why [p] must not be shown, or null if it may be.
  String? check(Proposal p, StoryIndex index) {
    if (p.grounding.isEmpty) return 'cites nothing in the story';
    for (final g in p.grounding) {
      final src = index.source(g.sourceId);
      if (src == null || src.text.substring(g.start, g.end) != g.quote) {
        return 'cites text that is not in the story';
      }
    }
    return null;
  }
}

/// What the author has done with proposals. Nothing in here is canon.
class ProposalLedger {
  ProposalLedger({this.guard = const ProposalGuard()});
  final ProposalGuard guard;
  final _open = <String, Proposal>{};
  final _rejected = <String>{};

  List<Proposal> get open => List.unmodifiable(_open.values);

  /// Adds the proposals the guard allows and returns them.
  List<Proposal> offer(List<Proposal> proposals, StoryIndex index) {
    final shown = <Proposal>[];
    for (final p in proposals) {
      if (_rejected.contains(p.id) || guard.check(p, index) != null) continue;
      _open[p.id] = p;
      shown.add(p);
    }
    return shown;
  }

  void reject(String id) {
    _open.remove(id);
    _rejected.add(id);
  }

  /// The author approved [id]. Returns the entry to hand to the canon writer, and
  /// removes it from the ledger. Calling this is the only way a proposal leaves it.
  ApprovedProposal? approve(String id) {
    final p = _open.remove(id);
    if (p == null) return null;
    return ApprovedProposal(
      text: p.text,
      question: p.question,
      grounding: p.grounding,
    );
  }
}

class ApprovedProposal {
  const ApprovedProposal({
    required this.text,
    required this.question,
    required this.grounding,
  });
  final String text;
  final String question;
  final List<EvidenceRef> grounding;
}
