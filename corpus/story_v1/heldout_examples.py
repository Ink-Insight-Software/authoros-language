"""The held-out examples for story_v1. WRITTEN BEFORE any rule of the pipeline, and
not looked at while the rules were written (see docs/story-grounding/evaluation.md).

Token notation, one string per sentence, tokens separated by spaces:

    surface/POS[=lemma][@ROLE][#entity_id]

`lemma` is only given where it differs from the lower-cased surface. `build.py`
computes every character offset from the stored text; nothing here is an offset.

These were written by Claude as test cases for a rule-based pipeline. They are an
evaluation set, not training data for a model (see docs/story-grounding/design.md).
"""

from examples_common import Q, S, fact, ENTITIES  # noqa: F401  (ENTITIES used by build.py)

HELDOUT = [
    # --- location, direct and derived ---------------------------------------------
    {
        "id": "h01_derived_location",
        "sources": [S("h01", "Rowan buried the lantern behind the old mill at dusk.",
            "Rowan/PROPN@SUBJECT#char_rowan buried/VERB=bury@ACTION the/DET "
            "lantern/NOUN@OBJECT#item_lantern behind/ADP the/DET old/ADJ "
            "mill/NOUN@LOCATION#place_mill at/ADP dusk/NOUN@TIME ./PUNCT",
            [fact("char_rowan", "bury", "item_lantern", location="place_mill", time="at dusk")])],
        "query": Q("Where did the lantern end up?", "retrieve_location", ["item_lantern"], None,
                   "behind the old mill", "DERIVED", ["h01"]),
    },
    {
        "id": "h02_direct_location",
        "sources": [S("h02", "Rowan buried the lantern behind the old mill at dusk.",
            "Rowan/PROPN@SUBJECT#char_rowan buried/VERB=bury@ACTION the/DET "
            "lantern/NOUN@OBJECT#item_lantern behind/ADP the/DET old/ADJ "
            "mill/NOUN@LOCATION#place_mill at/ADP dusk/NOUN@TIME ./PUNCT",
            [fact("char_rowan", "bury", "item_lantern", location="place_mill", time="at dusk")])],
        "query": Q("Where did Rowan bury the lantern?", "retrieve_location",
                   ["char_rowan", "item_lantern"], "bury", "behind the old mill", "STATED", ["h02"]),
    },
    # --- passive -------------------------------------------------------------------
    {
        "id": "h03_passive_agent",
        "sources": [S("h03", "The letter was burned by Edda in the kitchen.",
            "The/DET letter/NOUN@OBJECT#item_letter was/AUX burned/VERB=burn@ACTION by/ADP "
            "Edda/PROPN@SUBJECT#char_edda in/ADP the/DET kitchen/NOUN@LOCATION#place_kitchen ./PUNCT",
            [fact("char_edda", "burn", "item_letter", location="place_kitchen")])],
        "query": Q("Who burned the letter?", "retrieve_agent", ["item_letter"], "burn",
                   "Edda", "STATED", ["h03"]),
    },
    # --- negation and modality -----------------------------------------------------
    {
        "id": "h04_negation_yes_no",
        "sources": [S("h04", "Tom did not open the cellar door.",
            "Tom/PROPN@SUBJECT#char_tom did/AUX not/PART open/VERB@ACTION the/DET "
            "cellar/NOUN@OBJECT#item_cellar_door door/NOUN@OBJECT#item_cellar_door ./PUNCT",
            [fact("char_tom", "open", "item_cellar_door", polarity="negated")])],
        "query": Q("Did Tom open the cellar door?", "yes_no", ["char_tom", "item_cellar_door"],
                   "open", "No", "STATED", ["h04"]),
    },
    {
        "id": "h05_modality_is_not_an_event",
        "sources": [S("h05", "Edda might take the map to the harbour.",
            "Edda/PROPN@SUBJECT#char_edda might/AUX take/VERB@ACTION the/DET map/NOUN@OBJECT#item_map "
            "to/ADP the/DET harbour/NOUN@LOCATION#place_harbour ./PUNCT",
            [fact("char_edda", "take", "item_map", destination="place_harbour", modality="possible")])],
        "query": Q("Did Edda take the map?", "yes_no", ["char_edda", "item_map"], "take",
                   None, "UNKNOWN", ["h05"], note="possibility only"),
    },
    # --- reported speech and dialogue ---------------------------------------------
    {
        "id": "h06_reported_speech",
        "sources": [S("h06", "Iven said that Rowan stole the horse.",
            "Iven/PROPN@SUBJECT#char_iven said/VERB=say@ACTION that/SCONJ Rowan/PROPN@SUBJECT#char_rowan "
            "stole/VERB=steal@ACTION the/DET horse/NOUN@OBJECT#item_horse ./PUNCT",
            [fact("char_rowan", "steal", "item_horse",
                  attribution={"speaker": "char_iven", "kind": "reported"})])],
        "query": Q("Did Rowan steal the horse?", "yes_no", ["char_rowan", "item_horse"], "steal",
                   "Yes", "STATED", ["h06"], attribution={"speaker": "char_iven", "kind": "reported"}),
    },
    {
        "id": "h07_quoted_speech",
        "sources": [S("h07", "“I took the ring,” said Iven.",
            "“/PUNCT I/PRON@SUBJECT#char_iven took/VERB=take@ACTION the/DET ring/NOUN@OBJECT#item_ring "
            ",/PUNCT ”/PUNCT said/VERB=say Iven/PROPN#char_iven ./PUNCT",
            [fact("char_iven", "take", "item_ring",
                  attribution={"speaker": "char_iven", "kind": "reported"})])],
        "query": Q("Who took the ring?", "retrieve_agent", ["item_ring"], "take",
                   "Iven", "STATED", ["h07"], attribution={"speaker": "char_iven", "kind": "reported"}),
    },
    # --- pronouns ------------------------------------------------------------------
    {
        "id": "h08_pronoun_resolved",
        "sources": [
            S("h08a", "Tom lit the stove.",
              "Tom/PROPN@SUBJECT#char_tom lit/VERB=light@ACTION the/DET stove/NOUN@OBJECT#item_stove ./PUNCT",
              [fact("char_tom", "light", "item_stove")]),
            S("h08b", "He closed the shutters before sunrise.",
              "He/PRON@SUBJECT#char_tom closed/VERB=close@ACTION the/DET "
              "shutters/NOUN=shutter@OBJECT#item_shutter before/ADP sunrise/NOUN@TIME ./PUNCT",
              [fact("char_tom", "close", "item_shutter", time="before sunrise")]),
        ],
        "query": Q("Who closed the shutters?", "retrieve_agent", ["item_shutter"], "close",
                   "Tom", "STATED", ["h08b"]),
    },
    {
        "id": "h09_pronoun_unresolved",
        "sources": [
            S("h09a", "Edda met Mara at the pier.",
              "Edda/PROPN@SUBJECT#char_edda met/VERB=meet@ACTION Mara/PROPN@OBJECT#char_mara at/ADP "
              "the/DET pier/NOUN@LOCATION#place_pier ./PUNCT",
              [fact("char_edda", "meet", "char_mara", location="place_pier")]),
            S("h09b", "She dropped the basket.",
              "She/PRON@SUBJECT dropped/VERB=drop@ACTION the/DET basket/NOUN@OBJECT#item_basket ./PUNCT",
              [fact(None, "drop", "item_basket", unresolved_subject=True)]),
        ],
        "query": Q("Who dropped the basket?", "retrieve_agent", ["item_basket"], "drop",
                   None, "UNKNOWN", ["h09b"], note="unresolved reference"),
    },
    # --- conflict and unknown ------------------------------------------------------
    {
        "id": "h10_conflict_colour",
        "sources": [
            S("h10a", "The gate was green.",
              "The/DET gate/NOUN@SUBJECT#item_gate was/AUX green/ADJ@ATTRIBUTE ./PUNCT",
              [fact("item_gate", "be", None, attribute="green")]),
            S("h10b", "Edda waited by the red gate.",
              "Edda/PROPN@SUBJECT#char_edda waited/VERB=wait@ACTION by/ADP the/DET red/ADJ@ATTRIBUTE "
              "gate/NOUN@LOCATION#item_gate ./PUNCT",
              [fact("char_edda", "wait", None, location="item_gate"),
               fact("item_gate", "be", None, attribute="red")]),
        ],
        "query": Q("What colour is the gate?", "retrieve_attribute", ["item_gate"], None,
                   None, "CONFLICT", ["h10a", "h10b"], answers=["green", "red"]),
    },
    {
        "id": "h11_unknown_no_witness",
        "sources": [S("h11", "Rowan lit the lantern in the barn.",
            "Rowan/PROPN@SUBJECT#char_rowan lit/VERB=light@ACTION the/DET lantern/NOUN@OBJECT#item_lantern "
            "in/ADP the/DET barn/NOUN@LOCATION#place_barn ./PUNCT",
            [fact("char_rowan", "light", "item_lantern", location="place_barn")])],
        "query": Q("Who saw Rowan light the lantern?", "retrieve_agent", ["char_rowan", "item_lantern"],
                   "see", None, "UNKNOWN", [], offer_proposal=True),
    },
    # --- time, manner, object ------------------------------------------------------
    {
        "id": "h12_time",
        "sources": [S("h12", "Edda returned the book after midnight.",
            "Edda/PROPN@SUBJECT#char_edda returned/VERB=return@ACTION the/DET book/NOUN@OBJECT#item_book "
            "after/ADP midnight/NOUN@TIME ./PUNCT",
            [fact("char_edda", "return", "item_book", time="after midnight")])],
        "query": Q("When did Edda return the book?", "retrieve_time", ["char_edda", "item_book"],
                   "return", "after midnight", "STATED", ["h12"]),
    },
    {
        "id": "h13_manner",
        "sources": [S("h13", "Tom carefully carried the jar across the yard.",
            "Tom/PROPN@SUBJECT#char_tom carefully/ADV@MANNER carried/VERB=carry@ACTION the/DET "
            "jar/NOUN@OBJECT#item_jar across/ADP the/DET yard/NOUN@LOCATION#place_yard ./PUNCT",
            [fact("char_tom", "carry", "item_jar", location="place_yard", manner="carefully")])],
        "query": Q("How did Tom carry the jar?", "retrieve_manner", ["char_tom", "item_jar"],
                   "carry", "carefully", "STATED", ["h13"]),
    },
    {
        "id": "h14_object_with_irregular_verb",
        "sources": [S("h14", "Rowan left the basket on the bridge.",
            "Rowan/PROPN@SUBJECT#char_rowan left/VERB=leave@ACTION the/DET basket/NOUN@OBJECT#item_basket "
            "on/ADP the/DET bridge/NOUN@LOCATION#place_bridge ./PUNCT",
            [fact("char_rowan", "leave", "item_basket", location="place_bridge")])],
        "query": Q("What did Rowan leave on the bridge?", "retrieve_object",
                   ["char_rowan", "place_bridge"], "leave", "the basket", "STATED", ["h14"]),
    },
    # --- static facts and synonyms --------------------------------------------------
    {
        "id": "h15_static_location_with_attribute",
        "sources": [S("h15", "The silver key was beneath the chapel floor.",
            "The/DET silver/ADJ@ATTRIBUTE key/NOUN@SUBJECT#item_key was/AUX beneath/ADP the/DET "
            "chapel/NOUN@LOCATION#place_chapel_floor floor/NOUN@LOCATION#place_chapel_floor ./PUNCT",
            [fact("item_key", "be", None, location="place_chapel_floor"),
             fact("item_key", "be", None, attribute="silver")])],
        "query": Q("Where is the key?", "retrieve_location", ["item_key"], None,
                   "beneath the chapel floor", "STATED", ["h15"]),
    },
    {
        "id": "h16_synonym_in_question",
        "sources": [S("h16", "Mara hid the key beneath the chapel floor.",
            "Mara/PROPN@SUBJECT#char_mara hid/VERB=hide@ACTION the/DET key/NOUN@OBJECT#item_key "
            "beneath/ADP the/DET chapel/NOUN@LOCATION#place_chapel_floor floor/NOUN@LOCATION#place_chapel_floor "
            "./PUNCT",
            [fact("char_mara", "hide", "item_key", location="place_chapel_floor")])],
        "query": Q("Where did Mara conceal the key?", "retrieve_location", ["char_mara", "item_key"],
                   "hide", "beneath the chapel floor", "STATED", ["h16"]),
    },
    # --- tagging only ---------------------------------------------------------------
    {
        "id": "h17_tag_clitic_and_possessive",
        "sources": [S("h17", "Edda didn't see the Duke's boat.",
            "Edda/PROPN did/AUX n't/PART=not see/VERB the/DET Duke/PROPN 's/PART boat/NOUN ./PUNCT", [])],
        "query": None,
    },
    {
        "id": "h18_tag_aux_participle_progressive",
        "sources": [S("h18", "Mara had hidden the lamp, and then she was sleeping.",
            "Mara/PROPN had/AUX hidden/VERB=hide the/DET lamp/NOUN ,/PUNCT and/CCONJ then/ADV she/PRON "
            "was/AUX sleeping/VERB=sleep ./PUNCT", [])],
        "query": None,
    },
]
