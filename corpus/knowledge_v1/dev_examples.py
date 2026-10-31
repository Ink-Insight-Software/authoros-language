"""The development examples for knowledge_v1: the ones the knowledge rules were written
against. Different characters and objects from heldout_examples.py. Original sentences
written by Claude; an evaluation set, not training data for a model.
"""

from common import K, TL, ev, exp_knows, exp_leaks, exp_when, exp_who, knows, leaks_query, prop, src, when, who

LAMP = prop("char_edda", "hide", "item_lantern")
MAP = prop("char_edda", "take", "item_map")
RING = prop("char_edda", "sell", "item_ring")
LETTER = prop("char_rowan", "steal", "item_letter")
HIDE_RING = prop("char_edda", "hide", "item_ring")

DEV = [
    K("kd01_told_and_confirmed",
      TL("chapter_01", "chapter_02"),
      [src("d01a", "chapter_01", "Edda hid the lantern in the barn."),
       src("d01b", "chapter_02", "Rowan told Tom that Edda hid the lantern.")],
      knows("Does Tom know Edda hid the lantern?", "char_tom", LAMP, "chapter_02"),
      exp_knows("KNOWS", "STATED", "TOLD", ["d01b"], canon=True),
      [ev("char_edda", LAMP, "KNOWS", "EXPERIENCED", "d01a"), ev("char_tom", LAMP, "KNOWS", "TOLD", "d01b")]),

    K("kd02_told_but_not_confirmed",
      TL("chapter_01", "chapter_02"),
      [src("d02a", "chapter_02", "Rowan told Tom that Edda hid the lantern.")],
      knows("Does Tom know Edda hid the lantern?", "char_tom", LAMP, "chapter_02"),
      exp_knows("BELIEVES", "STATED", "TOLD", ["d02a"], canon=None),
      [ev("char_tom", LAMP, "BELIEVES", "TOLD", "d02a")]),

    K("kd03_saw_it_happen",
      TL("chapter_01", "chapter_02"),
      [src("d03a", "chapter_01", "Edda took the map from the table."),
       src("d03b", "chapter_01", "Tom saw Edda take the map.")],
      knows("Does Tom know Edda took the map?", "char_tom", MAP, "chapter_02"),
      exp_knows("KNOWS", "STATED", "WITNESSED", ["d03b"], canon=True),
      [ev("char_edda", MAP, "KNOWS", "EXPERIENCED", "d03a"), ev("char_tom", MAP, "KNOWS", "WITNESSED", "d03b")]),

    K("kd04_overheard",
      TL("chapter_01", "chapter_02"),
      [src("d04a", "chapter_01", "Edda sold the ring."),
       src("d04b", "chapter_02", "Rowan overheard that Edda sold the ring.")],
      knows("Does Rowan know Edda sold the ring?", "char_rowan", RING, "chapter_02"),
      exp_knows("KNOWS", "STATED", "OVERHEARD", ["d04b"], canon=True),
      [ev("char_edda", RING, "KNOWS", "EXPERIENCED", "d04a"), ev("char_rowan", RING, "KNOWS", "OVERHEARD", "d04b")]),

    K("kd05_read_about_it",
      TL("chapter_01", "chapter_02"),
      [src("d05a", "chapter_01", "Edda sold the ring."),
       src("d05b", "chapter_02", "Tom read that Edda sold the ring.")],
      knows("Does Tom know Edda sold the ring?", "char_tom", RING, "chapter_02"),
      exp_knows("KNOWS", "STATED", "READ", ["d05b"], canon=True)),

    K("kd06_worked_it_out",
      TL("chapter_01", "chapter_02"),
      [src("d06a", "chapter_01", "Edda took the map."),
       src("d06b", "chapter_02", "Lucia realized that Edda took the map.")],
      knows("Does Lucia know Edda took the map?", "char_lucia", MAP, "chapter_02"),
      exp_knows("KNOWS", "STATED", "INFERRED", ["d06b"], canon=True)),

    K("kd07_suspicion_is_not_knowledge",
      TL("chapter_01", "chapter_02"),
      [src("d07a", "chapter_02", "Lucia suspected that Rowan stole the letter.")],
      knows("Does Lucia know Rowan stole the letter?", "char_lucia", LETTER, "chapter_02"),
      exp_knows("SUSPECTS", "STATED", "INFERRED", ["d07a"], canon=None),
      [ev("char_lucia", LETTER, "SUSPECTS", "INFERRED", "d07a")]),

    K("kd08_the_state_at_the_asked_point_not_the_latest",
      TL("chapter_01", "chapter_02", "chapter_03"),
      [src("d08a", "chapter_01", "Tom believed that the sword was in the cellar."),
       src("d08b", "chapter_03", "Tom learned that the sword was on the roof.")],
      knows("Does Tom know the sword was in the cellar by Chapter 2?", "char_tom",
            prop("item_sword", "be", None, location="place_cellar"), "chapter_02"),
      exp_knows("BELIEVES", "STATED", None, ["d08a"], canon=False),
      [ev("char_tom", prop("item_sword", "be", None, location="place_cellar"), "BELIEVES", None, "d08a"),
       ev("char_tom", prop("item_sword", "be", None, location="place_roof"), "KNOWS", None, "d08b")]),

    K("kd09_a_chapter_means_its_scenes_too",
      TL("chapter_01", "chapter_02_scene_01", "chapter_02_scene_03", "chapter_03"),
      [src("d09a", "chapter_01", "Edda took the map."),
       src("d09b", "chapter_02_scene_03", "Rowan told Tom that Edda took the map.")],
      knows("Does Tom know Edda took the map by Chapter 2?", "char_tom", MAP, "chapter_02"),
      exp_knows("KNOWS", "STATED", "TOLD", ["d09b"], canon=True)),

    K("kd10_a_scene_point_is_before_its_later_scenes",
      TL("chapter_01", "chapter_02_scene_01", "chapter_02_scene_03", "chapter_03"),
      [src("d10a", "chapter_01", "Edda took the map."),
       src("d10b", "chapter_02_scene_03", "Rowan told Tom that Edda took the map.")],
      knows("Does Tom know Edda took the map by Chapter 2, Scene 1?", "char_tom", MAP, "chapter_02_scene_01"),
      exp_knows(None, "UNKNOWN", None, ["d10b"], note="first recorded acquisition is later")),

    K("kd11_nobody_has_learned_it",
      TL("chapter_01", "chapter_02"),
      [src("d11a", "chapter_01", "Edda took the map."),
       src("d11b", "chapter_02", "Rowan told Tom that Lucia sold the ring.")],
      who("Who knows Lucia sold the ring by Chapter 2?", prop("char_lucia", "sell", "item_ring"), "chapter_02"),
      exp_who([], "UNKNOWN", [])),

    K("kd12_acting_on_a_hidden_thing_unaware",
      TL("chapter_01", "chapter_02", "chapter_03"),
      [src("d12a", "chapter_01", "Edda hid the ring inside the chest."),
       src("d12b", "chapter_02", "Rowan searched inside the chest.")],
      leaks_query(),
      exp_leaks([("char_rowan", "d12b", "d12a")])),

    K("kd13_the_hider_knows",
      TL("chapter_01", "chapter_02"),
      [src("d13a", "chapter_01", "Edda hid the ring inside the chest."),
       src("d13b", "chapter_02", "Edda opened the chest.")],
      leaks_query(),
      exp_leaks([])),

    K("kd14_saw_it_hidden_then_searched",
      TL("chapter_01", "chapter_02", "chapter_03"),
      [src("d14a", "chapter_01", "Edda hid the ring inside the chest."),
       src("d14b", "chapter_02", "Rowan saw Edda hide the ring."),
       src("d14c", "chapter_03", "Rowan searched inside the chest.")],
      leaks_query(),
      exp_leaks([])),

    K("kd15_no_time_means_the_end_of_the_story",
      TL("chapter_01", "chapter_02", "chapter_09"),
      [src("d15a", "chapter_09", "Rowan told Tom that Edda took the map."),
       src("d15b", "chapter_01", "Edda took the map.")][::-1],
      knows("Does Tom know Edda took the map?", "char_tom", MAP, None),
      exp_knows("KNOWS", "STATED", "TOLD", ["d15a"], canon=True)),

    K("kd16_when_never",
      TL("chapter_01", "chapter_02"),
      [src("d16a", "chapter_01", "Edda took the map.")],
      when("When did Tom learn that Edda took the map?", "char_tom", MAP),
      exp_when(None, "UNKNOWN", [])),

    K("kd17_the_authors_own_record",
      TL("chapter_01", "chapter_02"),
      [src("d17a", "chapter_01", "Edda took the map.")],
      knows("Does Lucia know Edda took the map by Chapter 2?", "char_lucia", MAP, "chapter_02"),
      exp_knows("KNOWS", "STATED", "AUTHOR_ENTERED", ["note_lucia_2"], canon=True),
      author=[{"record_id": "note_lucia_2", "character_id": "char_lucia", "story_time_id": "chapter_01",
               "knowledge_state": "KNOWS", "text": "Edda took the map.",
               "note": "Lucia saw it from the window; the author wants her to know from the start."}]),

    K("kd18_a_pronoun_inside_what_was_said",
      TL("chapter_01", "chapter_02"),
      [src("d18a", "chapter_01", "Edda took the map."),
       src("d18b", "chapter_02", "Rowan told Tom that she took the map.")],
      knows("Does Tom know Edda took the map?", "char_tom", MAP, "chapter_02"),
      exp_knows("KNOWS", "STATED", "TOLD", ["d18b"], canon=True)),

    K("kd19_might_know_is_not_knowing",
      TL("chapter_01", "chapter_02"),
      [src("d19a", "chapter_02", "Tom might know that Edda took the map.")],
      knows("Does Tom know Edda took the map?", "char_tom", MAP, "chapter_02"),
      exp_knows(None, "UNKNOWN", None, ["d19a"], note="possibility only")),

    K("kd20_who_knows_two_ways",
      TL("chapter_01", "chapter_02"),
      [src("d20a", "chapter_01", "Edda sold the ring."),
       src("d20b", "chapter_02", "Tom watched Edda sell the ring.")],
      who("Who knows Edda sold the ring?", RING, "chapter_02"),
      exp_who(["char_edda", "char_tom"], "STATED", ["d20a", "d20b"])),

    K("kd21_the_story_denies_what_was_believed",
      TL("chapter_01", "chapter_02"),
      [src("d21a", "chapter_01", "Edda did not take the map."),
       src("d21b", "chapter_02", "Lucia believed that Edda took the map.")],
      knows("Does Lucia know Edda took the map?", "char_lucia", MAP, "chapter_02"),
      exp_knows("BELIEVES", "STATED", None, ["d21b"], canon=False)),
]
