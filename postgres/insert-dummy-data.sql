-- Insert dummy backlog entries for test user (UserID = 1)

BEGIN;

INSERT INTO "blm-system"."BacklogEntries" (
    "UserID", "Title", "Genre", "Platform", "Status", "Owned", "Interest",
    "ImageLink", "MainTime", "MainPlusExtraTime", "CompletionTime",
    "ReviewStars", "Review", "Note"
) VALUES (
    1,
    'The First Berserker Khazan',
    'Action, Adventure, Role-Playing',
    'PC',
    'In Progress',
    true,
    10,
    'https://howlongtobeat.com/games/141849_The_First_Berserker_Khazan.jpg',
    35,
    50,
    57,
    4,
    'Das Game ist einfach Liebe man und satisfing!',
    'Replay mit NG+ auf hoeherer Schwierigkeit!'
);

INSERT INTO "blm-system"."BacklogEntries" (
    "UserID", "Title", "Genre", "Platform", "Status", "Owned", "Interest",
    "ImageLink", "MainTime", "MainPlusExtraTime", "CompletionTime",
    "ReviewStars", "Review", "Note"
) VALUES (
    1,
    'Batman: Arkham Knight',
    'Third-Person, Action, Adventure, Beat em Up, Open World, Puzzle, Vehicular Combat',
    'PC',
    'Completed',
    true,
    8,
    'https://howlongtobeat.com/games/Batman_Arkham_Knight_Cover_Art.jpg',
    17,
    31,
    51,
    5,
    'I am the shadow, for Gotham!',
    'Endlich mal beenden haha'
);

INSERT INTO "blm-system"."BacklogEntries" (
    "UserID", "Title", "Genre", "Platform", "Status", "Owned", "Interest",
    "ImageLink", "MainTime", "MainPlusExtraTime", "CompletionTime",
    "ReviewStars", "Review", "Note"
) VALUES (
    1,
    'SnowRunner',
    'Racing/Driving, Simulation',
    'PC',
    'In Progress',
    true,
    7,
    'https://howlongtobeat.com/games/77675_SnowRunner.jpg',
    89,
    159,
    239,
    5,
    'So chiliig Gespräche mit den Jungs geht fast nirgendwo anders!',
    'Ich werd safe 1500 Stunden brauchen für alle Maps!'
);

INSERT INTO "blm-system"."BacklogEntries" (
    "UserID", "Title", "Genre", "Platform", "Status", "Owned", "Interest",
    "ImageLink", "MainTime", "MainPlusExtraTime", "CompletionTime",
    "ReviewStars", "Review", "Note"
) VALUES (
    1,
    'Super Mario Galaxy 2',
    'Platform, Adventure',
    'Nintendo Switch',
    'In Progress',
    true,
    10,
    'https://howlongtobeat.com/games/Super_Mario_Galaxy_2_Box_Art.jpg',
    13,
    21,
    33,
    4,
    'Extrem chilliges Spiel, das ich schon mal gespielt habe!',
    'Das Spiel ist sehr schwer, aber ich habe es schon mal gespielt!'
);

INSERT INTO "blm-system"."BacklogEntries" (
    "UserID", "Title", "Genre", "Platform", "Status", "Owned", "Interest",
    "ImageLink", "MainTime", "MainPlusExtraTime", "CompletionTime",
    "ReviewStars", "Review", "Note"
) VALUES (
    1,
    'Marvel''s Spider-Man 2',
    'Action, Adventure, Superhero',
    'Playstation 5',
    'Completed',
    true,
    10,
    'https://howlongtobeat.com/games/79769_Marvels_Spider-Man_2.png',
    17,
    24,
    29,
    4,
    'Das Spiel ist sehr schwer, aber ich habe es schon mal gespielt!',
    'Das Spiel ist sehr schwer, aber ich habe es schon mal gespielt!'
);

INSERT INTO "blm-system"."BacklogEntries" (
    "UserID", "Title", "Genre", "Platform", "Status", "Owned", "Interest",
    "ImageLink", "MainTime", "MainPlusExtraTime", "CompletionTime",
    "ReviewStars", "Review", "Note"
) VALUES (
    1,
    'Borderlands 4',
    'First-Person, Shooter',
    'PC',
    'In Progress',
    true,
    10,
    'https://howlongtobeat.com/games/91605_Borderlands_4.jpg',
    28,
    47,
    91,
    5,
    'Das Spiel ist sehr schwer, aber ich habe es schon mal gespielt!',
    'Das Spiel ist sehr schwer, aber ich habe es schon mal gespielt!'
);

INSERT INTO "blm-system"."BacklogEntries" (
    "UserID", "Title", "Genre", "Platform", "Status", "Owned", "Interest",
    "ImageLink", "MainTime", "MainPlusExtraTime", "CompletionTime",
    "ReviewStars", "Review", "Note"
) VALUES (
    1,
    'Sea of Thieves',
    'Action, Adventure, Open World',
    'Xbox Series X/S',
    'Completed',
    true,
    10,
    'https://howlongtobeat.com/games/38053_Sea_of_Thieves.jpg',
    72,
    226,
    0,
    3,
    'Das Spiel ist sehr schwer, aber ich habe es schon mal gespielt!',
    'Das Spiel ist sehr schwer, aber ich habe es schon mal gespielt!'
);

INSERT INTO "blm-system"."BacklogEntries" (
    "UserID", "Title", "Genre", "Platform", "Status", "Owned", "Interest",
    "ImageLink", "MainTime", "MainPlusExtraTime", "CompletionTime",
    "ReviewStars", "Review", "Note"
) VALUES (
    1,
    'Dispatch',
    'Action, Adventure, Management',
    'PC',
    'Not Started',
    false,
    6,
    'https://howlongtobeat.com/games/160618_Dispatch.jpg',
    9,
    10,
    17,
    1,
    'Das Spiel ist sehr schwer, aber ich habe es schon mal gespielt!',
    'Das Spiel ist sehr schwer, aber ich habe es schon mal gespielt!'
);

INSERT INTO "blm-system"."BacklogEntries" (
    "UserID", "Title", "Genre", "Platform", "Status", "Owned", "Interest",
    "ImageLink", "MainTime", "MainPlusExtraTime", "CompletionTime"
) VALUES (
    1,
    'Donkey Kong Country Mania',
    'Scrolling, Platform',
    'Super Nintendo',
    'Not Started',
    false,
    3,
    'https://howlongtobeat.com/games/162338_Donkey_Kong_Country_Mania.jpg',
    3.5,
    0,
    0
);

COMMIT;
