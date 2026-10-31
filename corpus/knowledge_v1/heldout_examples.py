"""The held-out examples for knowledge_v1. FROZEN: committed before any rule of the
knowledge stage was written. Do not edit to make a result better; a changed set is a
new set. Original sentences, written by Claude (the author of the rules), so they
share the author's blind spots; see docs/story-grounding/evaluation.md.
"""

from common import K, TL, ev, exp_knows, exp_leaks, exp_when, exp_who, knows, leaks_query, prop, src, when, who

HIDE = prop("char_mara", "hide", "item_key")
STOLE = prop("char_edda", "steal", "item_ledger")

HELDOUT = [
    K("kh01_told_then_ask_later",
      TL("chapter_01", "chapter_02", "chapter_03"),
      [src("h01a", "chapter_01", "Mara hid the key beneath the chapel floor."),
       src("h01b", "chapter_02", "Mara told Iven that she hid the key.")],
      knows("Does Iven know Mara hid the key by Chapter 3?", "char_iven", HIDE, "chapter_03"),
      exp_knows("KNOWS", "STATED", "TOLD", ["h01b"], canon=True),
      [ev("char_mara", HIDE, "KNOWS", "EXPERIENCED", "h01a"), ev("char_iven", HIDE, "KNOWS", "TOLD", "h01b")]),

    K("kh02_no_recorded_acquisition",
      TL("chapter_01", "chapter_02", "chapter_03"),
      [src("h02a", "chapter_01", "Mara hid the key beneath the chapel floor."),
       src("h02b", "chapter_02", "Mara told Iven that she hid the key.")],
      knows("Does Lucia know Mara hid the key by Chapter 3?", "char_lucia", HIDE, "chapter_03"),
      exp_knows(None, "UNKNOWN", None, [], note="no recorded acquisition found")),

    K("kh03_acquired_after_the_question_point",
      TL("chapter_01", "chapter_02", "chapter_03", "chapter_04"),
      [src("h03a", "chapter_01", "Mara hid the key beneath the chapel floor."),
       src("h03b", "chapter_04", "Iven saw Mara hide the key.")],
      knows("Does Iven know Mara hid the key by Chapter 3?", "char_iven", HIDE, "chapter_03"),
      exp_knows(None, "UNKNOWN", None, ["h03b"], note="first recorded acquisition is later"),
      [ev("char_mara", HIDE, "KNOWS", "EXPERIENCED", "h03a"), ev("char_iven", HIDE, "KNOWS", "WITNESSED", "h03b")]),

    K("kh04_false_belief_stays_separate_from_canon",
      TL("chapter_01", "chapter_02"),
      [src("h04a", "chapter_01", "The key was in the barn."),
       src("h04b", "chapter_02", "Iven believed that the key was under the pier.")],
      knows("Does Iven know the key was under the pier by Chapter 2?", "char_iven",
            prop("item_key", "be", None, location="place_pier"), "chapter_02"),
      exp_knows("BELIEVES", "STATED", None, ["h04b"], canon=False),
      [ev("char_iven", prop("item_key", "be", None, location="place_pier"), "BELIEVES", None, "h04b")]),

    K("kh05_belief_replaced_by_knowledge",
      TL("chapter_01", "chapter_02", "chapter_03"),
      [src("h05a", "chapter_01", "Iven believed that the key was under the pier."),
       src("h05b", "chapter_03", "Iven discovered that the key was in the barn.")],
      knows("Does Iven know the key was in the barn by Chapter 3?", "char_iven",
            prop("item_key", "be", None, location="place_barn"), "chapter_03"),
      exp_knows("KNOWS", "STATED", None, ["h05b"], canon=True),
      [ev("char_iven", prop("item_key", "be", None, location="place_pier"), "BELIEVES", None, "h05a"),
       ev("char_iven", prop("item_key", "be", None, location="place_barn"), "KNOWS", None, "h05b")]),

    K("kh06_being_told_is_not_knowing",
      TL("chapter_01", "chapter_02"),
      [src("h06a", "chapter_02", "Mara told Iven that Edda stole the ledger.")],
      knows("Does Iven know Edda stole the ledger?", "char_iven", STOLE, "chapter_02"),
      exp_knows("BELIEVES", "STATED", "TOLD", ["h06a"], canon=None),
      [ev("char_iven", STOLE, "BELIEVES", "TOLD", "h06a")]),

    K("kh07_text_says_unaware",
      TL("chapter_01", "chapter_02"),
      [src("h07a", "chapter_01", "Mara hid the key beneath the chapel floor."),
       src("h07b", "chapter_02", "Iven did not know that Mara hid the key.")],
      knows("Does Iven know Mara hid the key by Chapter 2?", "char_iven", HIDE, "chapter_02"),
      exp_knows("UNAWARE_IN_TEXT", "STATED", None, ["h07b"], canon=True),
      [ev("char_mara", HIDE, "KNOWS", "EXPERIENCED", "h07a"), ev("char_iven", HIDE, "UNAWARE_IN_TEXT", None, "h07b")]),

    K("kh08_who_knows_by_a_point",
      TL("chapter_01", "chapter_02", "chapter_03"),
      [src("h08a", "chapter_01", "Mara hid the key beneath the chapel floor."),
       src("h08b", "chapter_02", "Edda watched Mara hide the key."),
       src("h08c", "chapter_03", "Mara told Iven that she hid the key.")],
      who("Who knows Mara hid the key by Chapter 2?", HIDE, "chapter_02"),
      exp_who(["char_mara", "char_edda"], "STATED", ["h08a", "h08b"]),
      [ev("char_mara", HIDE, "KNOWS", "EXPERIENCED", "h08a"), ev("char_edda", HIDE, "KNOWS", "WITNESSED", "h08b"),
       ev("char_iven", HIDE, "KNOWS", "TOLD", "h08c")]),

    K("kh09_when_did_they_learn",
      TL("chapter_01", "chapter_02_scene_01", "chapter_02_scene_04", "chapter_03"),
      [src("h09a", "chapter_01", "Mara hid the key beneath the chapel floor."),
       src("h09b", "chapter_02_scene_04", "Mara told Iven that she hid the key.")],
      when("When did Iven learn that Mara hid the key?", "char_iven", HIDE),
      exp_when("chapter_02_scene_04", "STATED", ["h09b"])),

    K("kh10_acts_on_a_secret_before_learning_it",
      TL("chapter_01", "chapter_02", "chapter_03", "chapter_04"),
      [src("h10a", "chapter_01", "Mara hid the key beneath the chapel floor."),
       src("h10b", "chapter_03", "Iven dug beneath the chapel floor."),
       src("h10c", "chapter_04", "Mara told Iven that she hid the key.")],
      leaks_query(),
      exp_leaks([("char_iven", "h10b", "h10a")])),

    K("kh11_learns_first_so_no_leak",
      TL("chapter_01", "chapter_02", "chapter_03"),
      [src("h11a", "chapter_01", "Mara hid the key beneath the chapel floor."),
       src("h11b", "chapter_02", "Mara told Iven that she hid the key."),
       src("h11c", "chapter_03", "Iven dug beneath the chapel floor.")],
      leaks_query(),
      exp_leaks([])),

    K("kh12_two_passages_disagree_about_awareness",
      TL("chapter_01", "chapter_02"),
      [src("h12a", "chapter_02", "Iven knew that Mara hid the key."),
       src("h12b", "chapter_02", "Iven did not know that Mara hid the key.")],
      knows("Does Iven know Mara hid the key by Chapter 2?", "char_iven", HIDE, "chapter_02"),
      exp_knows(None, "CONFLICT", None, ["h12a", "h12b"])),

    K("kh13_perceiving_is_witnessing",
      TL("chapter_01", "chapter_02"),
      [src("h13a", "chapter_01", "Edda watched Mara hide the key.")],
      knows("Does Edda know Mara hid the key?", "char_edda", HIDE, "chapter_02"),
      exp_knows("KNOWS", "STATED", "WITNESSED", ["h13a"], canon=True),
      [ev("char_edda", HIDE, "KNOWS", "WITNESSED", "h13a")]),

    K("kh14_perceiving_with_a_pronoun",
      TL("chapter_01", "chapter_02"),
      [src("h14a", "chapter_01", "Mara hid the key."),
       src("h14b", "chapter_01", "Iven saw her hide it.")],
      knows("Does Iven know Mara hid the key?", "char_iven", HIDE, "chapter_02"),
      exp_knows("KNOWS", "STATED", "WITNESSED", ["h14b"], canon=True)),

    K("kh15_a_wrong_memory",
      TL("chapter_01", "chapter_02"),
      [src("h15a", "chapter_01", "Edda misremembered that the key was in the barn.")],
      knows("Does Edda know the key was in the barn?", "char_edda",
            prop("item_key", "be", None, location="place_barn"), "chapter_02"),
      exp_knows("MISREMEMBERS", "STATED", None, ["h15a"], canon=None),
      [ev("char_edda", prop("item_key", "be", None, location="place_barn"), "MISREMEMBERS", None, "h15a")]),

    K("kh16_the_author_says_unaware",
      TL("chapter_01", "chapter_02", "chapter_03"),
      [src("h16a", "chapter_01", "Mara hid the key beneath the chapel floor.")],
      knows("Does Lucia know Mara hid the key by Chapter 3?", "char_lucia", HIDE, "chapter_03"),
      exp_knows("AUTHOR_CONFIRMED_UNAWARE", "STATED", "AUTHOR_ENTERED", ["note_lucia_1"], canon=True),
      author=[{"record_id": "note_lucia_1", "character_id": "char_lucia", "story_time_id": "chapter_01",
               "knowledge_state": "AUTHOR_CONFIRMED_UNAWARE", "text": "Mara hid the key.",
               "note": "Lucia is away until Chapter 4 and has not been told."}]),

    K("kh17_synonym_in_the_question",
      TL("chapter_01", "chapter_02"),
      [src("h17a", "chapter_01", "Iven learned that Mara hid the key.")],
      knows("Did Iven learn that Mara concealed the key?", "char_iven", HIDE, "chapter_02"),
      exp_knows("KNOWS", "STATED", None, ["h17a"], canon=True),
      [ev("char_iven", HIDE, "KNOWS", None, "h17a")]),
]
