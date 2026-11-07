# Instructions for agents

GunFare is a first-person shooter. The work on this game is not complete. The game uses Godot 4.7. Players fight matches against bots. Players earn rank, unlocks, and Ascension levels.

## Language

Use ASD-STE100 Simplified Technical English for all text that you write for a person.
This rule applies at all times.
This rule applies to messages, documents, pull requests, and comments.
You can use the required syntax in code, in commands, and in file names.

Follow the writing rules in ASD-STE100:

- Use approved words, technical names, and technical verbs only.
- Use each approved word with the approved meaning.
- Use the active voice.
- Do not use a contraction.
- Do not use a semicolon.
- Write one topic in each sentence.
- Use a maximum of 25 words in a descriptive sentence.
- Use a maximum of 20 words in a procedure sentence.
- Write one instruction in each procedure sentence.
- Put a condition before the action.
- Use the same word for the same object.
- Do not use a noun cluster of more than three nouns.
- Keep the subject, the verb, and the articles.
- Use a vertical list for more than two items.
- Use a maximum of six sentences in a paragraph.

The STE dictionary is Part 2 of ASD-STE100. Use that dictionary when you choose words.

## Repository rules

Do not push a commit directly to the main branch.
Open a pull request for each change.
Write the pull request text in ASD-STE100.
Add the screenshots, diagrams, or tables that the template requests.
Do not put a secret in the repository.
Do not add an encryption key to `export_presets.cfg`.

## Version and updates

The version number is `application/config/version` in `project.godot`.
A release tag uses the same number, with a `v` prefix.
A release build can download a newer GitHub release.
The build closes, installs the files, and starts the game again.
A source build can show the new version. A source build must not install it.

## Tests

Run the progression test from the project directory:

`godot --headless --path . res://tests/test_progression.tscn`

Run the match test for 20 seconds:

`godot --headless --path . res://tests/smoke_match.tscn -- dustline tdm 20`

Run the pull-request text check:

`python tools/check_pr.py --self-test`
