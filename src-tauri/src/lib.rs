use pulldown_cmark::{html, Options, Parser};
use serde::Serialize;
use std::{env, fs, io::Write, path::{Path, PathBuf}};

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

    if content.starts_with('\u{feff}') {
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

// Stage the complete new contents beside the target before replacing it.
fn write_document(path: &Path, content: &str) -> Result<(), String> {
    fn replace_file(path: &Path, content: &str) -> std::io::Result<()> {
        let target = match fs::symlink_metadata(path) {
            Ok(_) => fs::canonicalize(path)?,
            Err(error) if error.kind() == std::io::ErrorKind::NotFound => path.to_path_buf(),
            Err(error) => return Err(error),
        };
        let parent = target.parent()
            .filter(|parent| !parent.as_os_str().is_empty())
            .unwrap_or_else(|| Path::new("."));
        let permissions = match fs::metadata(&target) {
            Ok(metadata) => {
                if !metadata.is_file() || metadata.permissions().readonly() {
                    return Err(std::io::Error::new(std::io::ErrorKind::PermissionDenied, "Documento non scrivibile"));
                }
                Some(metadata.permissions())
            }
            Err(error) if error.kind() == std::io::ErrorKind::NotFound => None,
            Err(error) => return Err(error),
        };
        let mut temporary = tempfile::NamedTempFile::new_in(parent)?;
        temporary.write_all(content.as_bytes())?;
        if let Some(permissions) = permissions {
            temporary.as_file().set_permissions(permissions)?;
        }
        temporary.as_file().sync_all()?;
        temporary.persist(target).map_err(|error| error.error)?;
        Ok(())
    }
    replace_file(path, content)
        .map_err(|error| format!("Impossibile salvare il file: {error}"))
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
fn open_document_path(path: String) -> Result<DocumentPayload, String> {
    document_from_path(Path::new(&path))
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
    write_document(&path, &content)?;
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
    write_document(&path, &content)?;
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

    let mut sanitizer = ammonia::Builder::default();
    sanitizer.add_tag_attributes("code", &["class"]);
    sanitizer.clean(&rendered).to_string()
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .invoke_handler(tauri::generate_handler![
            open_document,
            open_document_path,
            startup_document,
            save_document,
            save_document_as,
            render_markdown
        ])
        .run(tauri::generate_context!())
        .expect("errore durante l'avvio di Diaspro Markdown");
}


#[cfg(test)]
mod tests {
    use super::{document_from_path, render_markdown, write_document};
    use std::fs;

    #[test]
    fn save_replaces_existing_content_without_leaving_temp_files() {
        let directory = tempfile::tempdir().unwrap();
        let path = directory.path().join("documento.md");
        fs::write(&path, "vecchio contenuto più lungo").unwrap();
        write_document(&path, "# caffè 🐈").unwrap();
        assert_eq!(document_from_path(&path).unwrap().content, "# caffè 🐈");
        assert_eq!(fs::read_dir(directory.path()).unwrap().count(), 1);
    }

    #[test]
    fn save_creates_new_file_and_refuses_directory_target() {
        let directory = tempfile::tempdir().unwrap();
        let path = directory.path().join("nuovo.md");
        write_document(&path, "").unwrap();
        assert_eq!(fs::read(&path).unwrap(), b"");
        assert!(write_document(directory.path(), "invalid").is_err());
        assert!(path.is_file());
    }

    #[test]
    fn save_refuses_read_only_target_without_replacing_content() {
        let directory = tempfile::tempdir().unwrap();
        let path = directory.path().join("protetto.md");
        fs::write(&path, "originale").unwrap();
        let mut permissions = fs::metadata(&path).unwrap().permissions();
        permissions.set_readonly(true);
        fs::set_permissions(&path, permissions).unwrap();
        let result = write_document(&path, "modificato");
        assert!(result.is_err());
        assert_eq!(fs::read_to_string(&path).unwrap(), "originale");
        // Allow the temporary directory to be removed on Windows.
        let mut permissions = fs::metadata(&path).unwrap().permissions();
        permissions.set_readonly(false);
        fs::set_permissions(&path, permissions).unwrap();
    }

    #[test]
    fn preserves_mermaid_language_class() {
        let rendered = render_markdown(
            "```mermaid\ngraph TD\n  A[Inizio] --> B[Fine]\n```".to_string(),
        );

        assert!(rendered.contains("class=\"language-mermaid\""));
        assert!(rendered.contains("graph TD"));
    }

    #[test]
    fn sanitizer_still_removes_scripts() {
        let rendered = render_markdown("<script>alert('x')</script>\n\nTesto".to_string());

        assert!(!rendered.contains("<script"));
        assert!(rendered.contains("Testo"));
    }
}
