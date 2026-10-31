"""The development examples for story_v1: the ones the pipeline's rules were written
against. Same notation as heldout_examples.py. Written after the held-out set and
different from it in wording and content.

Written by Claude as test cases for a rule-based pipeline; an evaluation set, not
training data for a model.
"""

from examples_common import Q, S, fact

_KEY = S(
    "d01",
    "Mara quietly hid the silver key beneath the chapel floor before dawn.",
    "Mara/PROPN@SUBJECT#char_mara quietly/ADV@MANNER hid/VERB=hide@ACTION the/DET "
    "silver/ADJ@ATTRIBUTE key/NOUN@OBJECT#item_key beneath/ADP the/DET "
    "chapel/NOUN@LOCATION#place_chapel_floor floor/NOUN@LOCATION#place_chapel_floor "
    "before/ADP dawn/NOUN@TIME ./PUNCT",
    [fact("char_mara", "hide", "item_key", location="place_chapel_floor",
          time="before dawn", manner="quietly"),
     fact("item_key", "be", None, attribute="silver")],
)


def _key(suffix, query):
    """The key passage again, as the source of its own record."""
    return {"id": f"d01{suffix}", "sources": [dict(_KEY, source_id=f"d01{suffix}")], "query": query}


def _ev(q, ev):
    q["expected"]["evidence_ids"] = [ev]
    return q


DEV = [
    # --- one passage, many questions ------------------------------------------------
    _key("a_where", _ev(Q("Where did Mara hide the key?", "retrieve_location",
         ["char_mara", "item_key"], "hide", "beneath the chapel floor", "STATED", []), "d01a_where")),
    _key("b_end_up", _ev(Q("Where did the key end up?", "retrieve_location", ["item_key"], None,
         "beneath the chapel floor", "DERIVED", []), "d01b_end_up")),
    _key("c_when", _ev(Q("When did Mara hide the key?", "retrieve_time", ["char_mara", "item_key"],
         "hide", "before dawn", "STATED", []), "d01c_when")),
    _key("d_how", _ev(Q("How did Mara hide the key?", "retrieve_manner", ["char_mara", "item_key"],
         "hide", "quietly", "STATED", []), "d01d_how")),
    _key("e_colour", _ev(Q("What colour is the key?", "retrieve_attribute", ["item_key"], None,
         "silver", "STATED", []), "d01e_colour")),
    _key("f_who", _ev(Q("Who hid the silver key?", "retrieve_agent", ["item_key"], "hide",
         "Mara", "STATED", []), "d01f_who")),
    # --- pronouns -------------------------------------------------------------------
    {
        "id": "d07_pronouns",
        "sources": [
            S("d07a", "Mara found a silver key in the courtyard.",
              "Mara/PROPN@SUBJECT#char_mara found/VERB=find@ACTION a/DET silver/ADJ@ATTRIBUTE "
              "key/NOUN@OBJECT#item_key in/ADP the/DET courtyard/NOUN@LOCATION#place_courtyard ./PUNCT",
              [fact("char_mara", "find", "item_key", location="place_courtyard"),
               fact("item_key", "be", None, attribute="silver")]),
            S("d07b", "She hid it beneath the chapel floor.",
              "She/PRON@SUBJECT#char_mara hid/VERB=hide@ACTION it/PRON@OBJECT#item_key beneath/ADP "
              "the/DET chapel/NOUN@LOCATION#place_chapel_floor floor/NOUN@LOCATION#place_chapel_floor ./PUNCT",
              [fact("char_mara", "hide", "item_key", location="place_chapel_floor")]),
        ],
        "query": Q("Where did Mara hide the key?", "retrieve_location", ["char_mara", "item_key"],
                   "hide", "beneath the chapel floor", "STATED", ["d07b"]),
    },
    # --- passive ---------------------------------------------------------------------
    {
        "id": "d08_passive_no_agent",
        "sources": [S("d08", "The silver key was hidden beneath the chapel floor.",
            "The/DET silver/ADJ@ATTRIBUTE key/NOUN@OBJECT#item_key was/AUX hidden/VERB=hide@ACTION "
            "beneath/ADP the/DET chapel/NOUN@LOCATION#place_chapel_floor floor/NOUN@LOCATION#place_chapel_floor "
            "./PUNCT",
            [fact(None, "hide", "item_key", location="place_chapel_floor"),
             fact("item_key", "be", None, attribute="silver")])],
        "query": Q("Where is the key?", "retrieve_location", ["item_key"], None,
                   "beneath the chapel floor", "DERIVED", ["d08"]),
    },
    {
        "id": "d09_passive_agent_time",
        "sources": [S("d09", "The ledger was stolen by Iven during the storm.",
            "The/DET ledger/NOUN@OBJECT#item_ledger was/AUX stolen/VERB=steal@ACTION by/ADP "
            "Iven/PROPN@SUBJECT#char_iven during/ADP the/DET storm/NOUN@TIME ./PUNCT",
            [fact("char_iven", "steal", "item_ledger", time="during the storm")])],
        "query": Q("Who stole the ledger?", "retrieve_agent", ["item_ledger"], "steal",
                   "Iven", "STATED", ["d09"]),
    },
    # --- negation and modality ---------------------------------------------------------
    {
        "id": "d10_negation_yes_no",
        "sources": [S("d10", "Mara did not hide the key.",
            "Mara/PROPN@SUBJECT#char_mara did/AUX not/PART hide/VERB@ACTION the/DET key/NOUN@OBJECT#item_key ./PUNCT",
            [fact("char_mara", "hide", "item_key", polarity="negated")])],
        "query": Q("Did Mara hide the key?", "yes_no", ["char_mara", "item_key"], "hide",
                   "No", "STATED", ["d10"]),
    },
    {
        "id": "d11_negation_where",
        "sources": [S("d11", "Mara did not hide the key.",
            "Mara/PROPN@SUBJECT#char_mara did/AUX not/PART hide/VERB@ACTION the/DET key/NOUN@OBJECT#item_key ./PUNCT",
            [fact("char_mara", "hide", "item_key", polarity="negated")])],
        "query": Q("Where did Mara hide the key?", "retrieve_location", ["char_mara", "item_key"],
                   "hide", None, "UNKNOWN", [], offer_proposal=True),
    },
    {
        "id": "d12_modality",
        "sources": [S("d12", "Mara might hide the key.",
            "Mara/PROPN@SUBJECT#char_mara might/AUX hide/VERB@ACTION the/DET key/NOUN@OBJECT#item_key ./PUNCT",
            [fact("char_mara", "hide", "item_key", modality="possible")])],
        "query": Q("Did Mara hide the key?", "yes_no", ["char_mara", "item_key"], "hide",
                   None, "UNKNOWN", ["d12"], note="possibility only"),
    },
    {
        "id": "d30_never",
        "sources": [S("d30", "Iven never opened the cellar door.",
            "Iven/PROPN@SUBJECT#char_iven never/ADV opened/VERB=open@ACTION the/DET "
            "cellar/NOUN@OBJECT#item_cellar_door door/NOUN@OBJECT#item_cellar_door ./PUNCT",
            [fact("char_iven", "open", "item_cellar_door", polarity="negated")])],
        "query": Q("Did Iven open the cellar door?", "yes_no", ["char_iven", "item_cellar_door"],
                   "open", "No", "STATED", ["d30"]),
    },
    # --- reported and quoted speech ---------------------------------------------------
    {
        "id": "d13_told_that",
        "sources": [S("d13", "Mara told Iven that she hid the key.",
            "Mara/PROPN@SUBJECT#char_mara told/VERB=tell@ACTION Iven/PROPN@RECIPIENT#char_iven that/SCONJ "
            "she/PRON@SUBJECT#char_mara hid/VERB=hide@ACTION the/DET key/NOUN@OBJECT#item_key ./PUNCT",
            [fact("char_mara", "hide", "item_key",
                  attribution={"speaker": "char_mara", "kind": "reported"})])],
        "query": Q("Did Mara hide the key?", "yes_no", ["char_mara", "item_key"], "hide",
                   "Yes", "STATED", ["d13"], attribution={"speaker": "char_mara", "kind": "reported"}),
    },
    {
        "id": "d14_belief",
        "sources": [S("d14", "Iven believed that the key was under the pier.",
            "Iven/PROPN@SUBJECT#char_iven believed/VERB=believe@ACTION that/SCONJ the/DET "
            "key/NOUN@SUBJECT#item_key was/AUX under/ADP the/DET pier/NOUN@LOCATION#place_pier ./PUNCT",
            [fact("item_key", "be", None, location="place_pier",
                  attribution={"speaker": "char_iven", "kind": "belief"})])],
        "query": Q("Where is the key?", "retrieve_location", ["item_key"], None,
                   "under the pier", "STATED", ["d14"], attribution={"speaker": "char_iven", "kind": "belief"}),
    },
    {
        "id": "d18_quote_then_said",
        "sources": [S("d18", "\"I hid the key,\" said Mara.",
            "\"/PUNCT I/PRON@SUBJECT#char_mara hid/VERB=hide@ACTION the/DET key/NOUN@OBJECT#item_key ,/PUNCT "
            "\"/PUNCT said/VERB=say Mara/PROPN#char_mara ./PUNCT",
            [fact("char_mara", "hide", "item_key",
                  attribution={"speaker": "char_mara", "kind": "reported"})])],
        "query": Q("Who hid the key?", "retrieve_agent", ["item_key"], "hide", "Mara", "STATED",
                   ["d18"], attribution={"speaker": "char_mara", "kind": "reported"}),
    },
    {
        "id": "d19_said_then_quote",
        "sources": [S("d19", "Iven said, “Mara hid the key.”",
            "Iven/PROPN#char_iven said/VERB=say ,/PUNCT “/PUNCT Mara/PROPN@SUBJECT#char_mara "
            "hid/VERB=hide@ACTION the/DET key/NOUN@OBJECT#item_key ./PUNCT ”/PUNCT",
            [fact("char_mara", "hide", "item_key",
                  attribution={"speaker": "char_iven", "kind": "reported"})])],
        "query": Q("Did Mara hide the key?", "yes_no", ["char_mara", "item_key"], "hide", "Yes",
                   "STATED", ["d19"], attribution={"speaker": "char_iven", "kind": "reported"}),
    },
    # --- conflict, unknown, moved ------------------------------------------------------
    {
        "id": "d15_conflict",
        "sources": [
            S("d15a", "The key was black.",
              "The/DET key/NOUN@SUBJECT#item_key was/AUX black/ADJ@ATTRIBUTE ./PUNCT",
              [fact("item_key", "be", None, attribute="black")]),
            S("d15b", "Mara slid the silver key into her pocket.",
              "Mara/PROPN@SUBJECT#char_mara slid/VERB=slide@ACTION the/DET silver/ADJ@ATTRIBUTE "
              "key/NOUN@OBJECT#item_key into/ADP her/DET pocket/NOUN@LOCATION#place_pocket ./PUNCT",
              [fact("char_mara", "slide", "item_key", destination="place_pocket"),
               fact("item_key", "be", None, attribute="silver")]),
        ],
        "query": Q("What colour is the key?", "retrieve_attribute", ["item_key"], None, None,
                   "CONFLICT", ["d15a", "d15b"], answers=["black", "silver"]),
    },
    {
        "id": "d16_unknown_witness",
        "sources": [S("d16", "Mara hid the key beneath the chapel floor.",
            "Mara/PROPN@SUBJECT#char_mara hid/VERB=hide@ACTION the/DET key/NOUN@OBJECT#item_key beneath/ADP "
            "the/DET chapel/NOUN@LOCATION#place_chapel_floor floor/NOUN@LOCATION#place_chapel_floor ./PUNCT",
            [fact("char_mara", "hide", "item_key", location="place_chapel_floor")])],
        "query": Q("Who saw Mara hide the key?", "retrieve_agent", ["char_mara", "item_key"], "see",
                   None, "UNKNOWN", [], offer_proposal=True),
    },
    {
        "id": "d17_unknown_entity",
        "sources": [S("d17", "Iven walked to the market.",
            "Iven/PROPN@SUBJECT#char_iven walked/VERB=walk@ACTION to/ADP the/DET "
            "market/NOUN@LOCATION#place_market ./PUNCT",
            [fact("char_iven", "walk", None, destination="place_market")])],
        "query": Q("Where is the sword?", "retrieve_location", ["item_sword"], None, None,
                   "UNKNOWN", [], offer_proposal=True),
    },
    {
        "id": "d25_moved_later",
        "sources": [
            S("d25a", "Mara hid the key beneath the chapel floor.",
              "Mara/PROPN@SUBJECT#char_mara hid/VERB=hide@ACTION the/DET key/NOUN@OBJECT#item_key beneath/ADP "
              "the/DET chapel/NOUN@LOCATION#place_chapel_floor floor/NOUN@LOCATION#place_chapel_floor ./PUNCT",
              [fact("char_mara", "hide", "item_key", location="place_chapel_floor")]),
            S("d25b", "Iven took the key from the chapel.",
              "Iven/PROPN@SUBJECT#char_iven took/VERB=take@ACTION the/DET key/NOUN@OBJECT#item_key from/ADP "
              "the/DET chapel/NOUN@LOCATION#place_chapel ./PUNCT",
              [fact("char_iven", "take", "item_key", origin="place_chapel")]),
        ],
        "query": Q("Where is the key?", "retrieve_location", ["item_key"], None, None, "UNKNOWN",
                   ["d25a", "d25b"], note="later moved"),
    },
    # --- synonyms, tense, other slots -----------------------------------------------------
    {
        "id": "d20_synonym",
        "sources": [S("d20", "Iven grabbed the lamp from the shelf.",
            "Iven/PROPN@SUBJECT#char_iven grabbed/VERB=grab@ACTION the/DET lamp/NOUN@OBJECT#item_lamp from/ADP "
            "the/DET shelf/NOUN@LOCATION#place_shelf ./PUNCT",
            [fact("char_iven", "grab", "item_lamp", origin="place_shelf")])],
        "query": Q("What did Iven take?", "retrieve_object", ["char_iven"], "take", "the lamp",
                   "STATED", ["d20"]),
    },
    {
        "id": "d21_time_event",
        "sources": [S("d21", "Mara returned the ledger after the funeral.",
            "Mara/PROPN@SUBJECT#char_mara returned/VERB=return@ACTION the/DET ledger/NOUN@OBJECT#item_ledger "
            "after/ADP the/DET funeral/NOUN@TIME ./PUNCT",
            [fact("char_mara", "return", "item_ledger", time="after the funeral")])],
        "query": Q("When did Mara return the ledger?", "retrieve_time", ["char_mara", "item_ledger"],
                   "return", "after the funeral", "STATED", ["d21"]),
    },
    {
        "id": "d22_perfect_passive_present_question",
        "sources": [S("d22", "The key had been hidden by Mara.",
            "The/DET key/NOUN@OBJECT#item_key had/AUX been/AUX hidden/VERB=hide@ACTION by/ADP "
            "Mara/PROPN@SUBJECT#char_mara ./PUNCT",
            [fact("char_mara", "hide", "item_key")])],
        "query": Q("Who hides the key?", "retrieve_agent", ["item_key"], "hide", "Mara", "STATED", ["d22"]),
    },
    {
        "id": "d23_place_subject",
        "sources": [S("d23", "The chapel stood on the hill.",
            "The/DET chapel/NOUN@SUBJECT#place_chapel stood/VERB=stand@ACTION on/ADP the/DET "
            "hill/NOUN@LOCATION#place_hill ./PUNCT",
            [fact("place_chapel", "stand", None, location="place_hill")])],
        "query": Q("Where is the chapel?", "retrieve_location", ["place_chapel"], None,
                   "on the hill", "STATED", ["d23"]),
    },
    {
        "id": "d24_copular_colour",
        "sources": [S("d24", "The lantern was green.",
            "The/DET lantern/NOUN@SUBJECT#item_lantern was/AUX green/ADJ@ATTRIBUTE ./PUNCT",
            [fact("item_lantern", "be", None, attribute="green")])],
        "query": Q("What colour is the lantern?", "retrieve_attribute", ["item_lantern"], None,
                   "green", "STATED", ["d24"]),
    },
    {
        "id": "d29_recipient",
        "sources": [S("d29", "Iven gave Mara a letter at the pier.",
            "Iven/PROPN@SUBJECT#char_iven gave/VERB=give@ACTION Mara/PROPN@RECIPIENT#char_mara a/DET "
            "letter/NOUN@OBJECT#item_letter at/ADP the/DET pier/NOUN@LOCATION#place_pier ./PUNCT",
            [fact("char_iven", "give", "item_letter", recipient="char_mara", location="place_pier")])],
        "query": Q("Who gave Mara the letter?", "retrieve_agent", ["char_mara", "item_letter"], "give",
                   "Iven", "STATED", ["d29"]),
    },
    {
        "id": "d31_present_tense",
        "sources": [S("d31", "Edda hides letters behind the clock.",
            "Edda/PROPN@SUBJECT#char_edda hides/VERB=hide@ACTION letters/NOUN=letter@OBJECT#item_letter "
            "behind/ADP the/DET clock/NOUN@LOCATION#place_clock ./PUNCT",
            [fact("char_edda", "hide", "item_letter", location="place_clock")])],
        "query": Q("Where did Edda hide the letters?", "retrieve_location", ["char_edda", "item_letter"],
                   "hide", "behind the clock", "STATED", ["d31"]),
    },
    {
        "id": "d32_destination",
        "sources": [S("d32", "Tom carried the jar to the barn.",
            "Tom/PROPN@SUBJECT#char_tom carried/VERB=carry@ACTION the/DET jar/NOUN@OBJECT#item_jar to/ADP "
            "the/DET barn/NOUN@LOCATION#place_barn ./PUNCT",
            [fact("char_tom", "carry", "item_jar", destination="place_barn")])],
        "query": Q("Where did Tom carry the jar?", "retrieve_location", ["char_tom", "item_jar"],
                   "carry", "to the barn", "STATED", ["d32"]),
    },
    # --- tagging only --------------------------------------------------------------------
    {"id": "d26_tag_perfect_progressive", "query": None, "sources": [S("d26",
        "Mara had been waiting, but Iven wasn't ready.",
        "Mara/PROPN had/AUX been/AUX waiting/VERB=wait ,/PUNCT but/CCONJ Iven/PROPN was/AUX n't/PART=not "
        "ready/ADJ ./PUNCT", [])]},
    {"id": "d27_tag_interjection", "query": None, "sources": [S("d27", "Oh, she didn't know the way.",
        "Oh/INTJ ,/PUNCT she/PRON did/AUX n't/PART=not know/VERB the/DET way/NOUN ./PUNCT", [])]},
    {"id": "d28_tag_participle_adjective", "query": None, "sources": [S("d28",
        "The broken lantern stood in the corner.",
        "The/DET broken/ADJ lantern/NOUN stood/VERB=stand in/ADP the/DET corner/NOUN ./PUNCT", [])]},
    {"id": "d35_tag_name_like_a_noun", "query": None, "sources": [S("d35", "Rowan rowed the boat.",
        "Rowan/PROPN rowed/VERB=row the/DET boat/NOUN ./PUNCT", [])]},
    {"id": "d36_tag_adverb_adjective", "query": None, "sources": [S("d36", "She was quietly relieved.",
        "She/PRON was/AUX quietly/ADV relieved/ADJ ./PUNCT", [])]},
    {"id": "d37_tag_pronoun_perfect", "query": None, "sources": [S("d37",
        "Nobody had seen the old caretaker since Tuesday.",
        "Nobody/PRON had/AUX seen/VERB=see the/DET old/ADJ caretaker/NOUN since/ADP Tuesday/PROPN ./PUNCT",
        [])]},
    {"id": "d38_tag_number", "query": None, "sources": [S("d38", "Three crows sat on the roof.",
        "Three/NUM crows/NOUN=crow sat/VERB=sit on/ADP the/DET roof/NOUN ./PUNCT", [])]},
    {"id": "d39_tag_infinitive_marker", "query": None, "sources": [S("d39",
        "To hide the key, Mara waited until night.",
        "To/PART hide/VERB the/DET key/NOUN ,/PUNCT Mara/PROPN waited/VERB=wait until/ADP night/NOUN ./PUNCT",
        [])]},
]
