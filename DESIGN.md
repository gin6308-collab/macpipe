---
version: alpha
name: MacPipe Workbench
description: A dark, observable media-control workbench for MacPipe.
colors:
  background: "#08090A"
  panel: "#0F1011"
  surface: "#181A1D"
  elevated: "#20242A"
  text: "#F7F8F8"
  textSecondary: "#D0D6E0"
  textMuted: "#8A8F98"
  border: "#2A2F36"
  accent: "#30D158"
  search: "#38BDF8"
  selected: "#F59E0B"
  danger: "#FF3B30"
typography:
  body:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: 400
    lineHeight: 1.5
  mono:
    fontFamily: JetBrains Mono
    fontSize: 13px
    fontWeight: 400
    lineHeight: 1.5
rounded:
  sm: 6px
  md: 10px
  lg: 14px
spacing:
  sm: 8px
  md: 16px
  lg: 24px
components:
  button-primary:
    backgroundColor: "{colors.accent}"
    textColor: "#041008"
    rounded: "{rounded.sm}"
    padding: 10px
  panel:
    backgroundColor: "{colors.panel}"
    textColor: "{colors.text}"
    rounded: "{rounded.md}"
    padding: 16px
---

## Overview

MacPipe Workbench is a local, server-rendered control room for YouTube search and VLC playback. The interface should feel precise, dark, and terminal-adjacent without becoming an opaque terminal UI.

## Colors

Use a near-black canvas, restrained dark panels, and a small semantic accent set. Green means ready/play/success. Cyan means search/query. Amber means selected. Red means error.

## Typography

Use a readable sans face for UI labels and JetBrains Mono for commands, JSON, IDs, event logs, and debug output.

## Layout

The main page has four zones: search controls, ranked results, selected video/action panel, and observable debug panels. The debug information is not hidden behind developer tools; it is part of the product surface.

## Components

Buttons are plain, high-contrast, and form-backed. No custom JavaScript. Every meaningful action is a server POST and every state is readable through JSON debug endpoints.

## Do's and Don'ts

Do expose state, events, commands, and health. Do keep playback in VLC. Do use fixtures for deterministic demos. Don't add React, Vite, client-side state, or JS-heavy routing for this project.
