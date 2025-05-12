# Backlog Manager 🎮📒

A web-based backlog manager with a NextJS frontend, Go backend with REST-API and authentication and PostgreSQL database, deployed via Docker.
This is a private project of mine and still work in progress. 

## Overview 

This project implements a complete backlog manager to manage and organize games.
Users can create and manage their own backlog via their account. It stores all relevant data of
games such as name, genre, platform, status and personal notes. Users can use groups to sort their
games according to categories such as "Games I still want to play", "Games I'm currently playing" and
"Games I've already played through". This is made possible by simple drag &amp; drop.

## Features
- Connect all your game accounts (Only Steam for now)
- Import your games from Steam
- Import your existing backlog from a CSV file
- User authentication
- Categorization of games via self made groups
- Access your backlog from anywhere (cross platform native apps coming soon)

## Architecture

- **Frontend:** NextJS (T3 Stack)
- **Backend:** Typescript
- **Database:** PostgreSQL (pg-package)
- **Deployment:** Docker
