# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

MacMCP is a Model Context Protocol (MCP) server that exposes macOS accessibility APIs to Large Language Models (LLMs) over the stdio protocol. It allows LLMs like Claude to interact with macOS applications using the same accessibility APIs available to users, enabling them to perform user-level tasks such as browsing the web, creating presentations, working with spreadsheets, or using messaging applications.


This  is the REAL APP. We never use mocks. not in the code, not in the tests

## Memories

- our tests have access to a live macos UI. we can interact with the ui in tests

## Build and Development Commands

[... rest of the existing content remains unchanged ...]