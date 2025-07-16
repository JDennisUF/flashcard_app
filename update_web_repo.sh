#!/bin/bash

# Delete all files in the target directory
rm -rf ~/code/jdennisuf.github.io/flashcards/*

# Copy all files from the build/web directory to the target directory
cp -r ~/code/flashcards/flashcard_app/build/web/* ~/code/jdennisuf.github.io/flashcards/

echo "Web repo updated successfully." 