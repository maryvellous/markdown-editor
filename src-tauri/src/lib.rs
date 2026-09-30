use pulldown_cmark::{html, Options, Parser};
use serde::Serialize;
use std::{env, fs, path::{Path, PathBuf}};

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
struct DocumentPayload {
    path: String,
    name: String,
    content: String,
}

fn normalize_markdown_path(mut path: PathBuf) -> PathBuf {
    if path.extension().is_none() {
        path.set_extension("md");
    }
    path
}

fn document_from_path(path: &Path) -> Result<DocumentPayload, String> {
    let bytes = fs::read(path).map_err(|error| format!("Impossibile leggere il file: {error}"))?;
    let mut content = String::from_utf8(bytes)
        .map_err(|_| "Il file non è UTF-8 e non può essere aperto come Markdown.".to_string())?;

    if content.starts_with('﻿') {
        content.remove(0);
    }

    let name = path
        .file_name()
        .and_then(|value| value.to_str())
        .unwrap_or("documento.md")
        .to_string();

    Ok(DocumentPayload {
        path: path.to_string_lossy().into_owned(),
        name,
        content,
    })
}

#[tauri::command]
fn open_document() -> Result<Option<DocumentPayload>, String> {
    let Some(path) = rfd::FileDialog::new()
        .add_filter("Markdown", &["md", "markdown"])
        .add_filter("Testo", &["txt"])
        .pick_file()
    else {
        return Ok(None);
    };

    document_from_path(&path).map(Some)
}

#[tauri::command]
fn startup_document() -> Result<Option<DocumentPayload>, String> {
    let path = env::args_os()
        .skip(1)
        .map(PathBuf::from)
        .find(|candidate| candidate.is_file());

    match path {
        Some(path) => document_from_path(&path).map(Some),
        None => Ok(None),
    }
}

#[tauri::command]
fn save_document(path: String, content: String) -> Result<DocumentPayload, String> {
    let path = normalize_markdown_path(PathBuf::from(path));
    fs::write(&path, content.as_bytes())
        .map_err(|error| format!("Impossibile salvare il file: {error}"))?;
    document_from_path(&path)
}

#[tauri::command]
fn save_document_as(
    content: String,
    suggested_name: Option<String>,
) -> Result<Option<DocumentPayload>, String> {
    let suggested_name = suggested_name
        .filter(|name| !name.trim().is_empty())
        .unwrap_or_else(|| "documento.md".to_string());

    let Some(path) = rfd::FileDialog::new()
        .add_filter("Markdown", &["md", "markdown"])
        .set_file_name(&suggested_name)
        .save_file()
    else {
        return Ok(None);
    };

    let path = normalize_markdown_path(path);
    fs::write(&path, content.as_bytes())
        .map_err(|error| format!("Impossibile salvare il file: {error}"))?;
    document_from_path(&path).map(Some)
}

#[tauri::command]
fn render_markdown(markdown: String) -> String {
    let mut options = Options::empty();
    options.insert(Options::ENABLE_TABLES);
    options.insert(Options::ENABLE_FOOTNOTES);
    options.insert(Options::ENABLE_STRIKETHROUGH);
    options.insert(Options::ENABLE_TASKLISTS);
    options.insert(Options::ENABLE_HEADING_ATTRIBUTES);

    let parser = Parser::new_ext(&markdown, options);
    let mut rendered = String::new();
    html::push_html(&mut rendered, parser);

    ammonia::Builder::default().clean(&rendered).to_string()
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .invoke_handler(tauri::generate_handler![
            open_document,
            startup_document,
            save_document,
            save_document_as,
            render_markdown
        ])
        .run(tauri::generate_context!())
        .expect("errore durante l'avvio di Diaspro Markdown");
}
