(require 'yaml)
(require 'json)
(require 'org)
(require 'ox)

(make-local-variable 'pab/teaching-build-dir)
(make-local-variable 'pab/teaching-export-dir)
(make-local-variable 'pab/teaching-publish-dir)
(make-local-variable 'pab/teaching-publish-dirs)

(defun pab/teaching-load-settings ()
  "Load settings file."

  (let* ((json-object-type 'hash-table)
	 (json-array-type 'list)
	 (json-key-type 'string)
	 (json-settings (json-read-file "settings.json")))

    (setq pab/teaching-build-dir (gethash "build_dir" json-settings))
    (setq pab/teaching-export-dir (file-name-concat pab/teaching-build-dir (gethash "export_dir" json-settings)))
    (setq pab/teaching-publish-dir (file-name-concat pab/teaching-build-dir (gethash "publish_dir" json-settings)))
    (setq pab/teaching-publish-dirs (gethash "publish_dirs" json-settings))))

(defun pab/teaching-create-build ()
  "Create build enviroment."
  (interactive)
  (make-directory pab/teaching-build-dir :parents)
  (make-directory pab/teaching-export-dir :parents)
  (make-directory pab/teaching-publish-dir :parents)
  (maphash (lambda (hashkey hashval)
	     (make-directory (file-name-concat pab/teaching-publish-dir hashval) :parents))
	   pab/teaching-publish-dirs))

(defun pab/teaching-export-to-backend (backends &optional outfile post-process)
  "Export at point using BACKENDS.
BACKENDS should be a list of backends to use.

For example ('html), ('html 'tex)

Currently implemented are html and tex.

If OUTFILE is set, export to that file in the pab/teaching-export-dir directory
with appropriate file extension for echo backend in BACKENDS
Otherwise let org decide the filename

If provided, POST-PROCESS should be an elisp function with one mandatory
argument containing a filename.
The function will be called after the org-export to post-process the result."


  (dolist (backend backends)
    (let ((ext (cond ((equal backend 'html) "html")
		     ((equal backend 'latex) "tex")))
	  (filename nil))
      (if outfile
	  (setq filename (file-name-concat pab/teaching-export-dir (format "%s.%s" outfile ext)))
	(setq filename (org-export-output-file-name (format ".%s" ext) t pab/teaching-export-dir)))
      (org-export-to-file backend filename nil t nil t nil post-process))))

(defun prepend-hash-as-yaml-frontmatter (filename hash)
  "Prepend HASH to  FILENAME.

HASH should be a hash and FILENAME the name of a file.

HASH is converted to YAML and prepended as frontmatter to FILENAME.
The result is of the form

---
<yaml>
---

<filecontents>"

  (let* ((yaml-contents (yaml-encode hash))
	 (yaml-frontmatter (format "---\n%s\n---\n\n" yaml-contents)))

    (with-temp-buffer
      (insert yaml-frontmatter)
      (insert-file-contents filename)
      (write-region nil nil filename))))

(defun pab/teaching-export-file-name ()
  "Construct the file-name for export.
returns nil if EXPORT_FILE_NAME is already set
otherwise builds filename as <week>_<lec>_<name>"

  (unless (org-entry-get nil "EXPORT_FILE_NAME")
    (let ((name (org-entry-get-with-inheritance "NAME"))
	  (week (org-entry-get-with-inheritance "WEEK"))
	  (lec (org-entry-get-with-inheritance "LECTURE")))
      (format "%s_%s_%s" week lec name))))

(defun pab/teaching-export-subtopic-file-name (filename_prefix)
  "Construct the file-name for subtopic export.
Accepts one argument FILENAME_PREFIX

Returns nil if EXPORT_FILE_NAME is already set.
Otherwise return FILENAME-CUSTOM_ID where CUSTOM_ID is obtained from the tags."

  (unless (org-entry-get nil "EXPORT_FILE_NAME")
    (let ((topic (org-entry-get-with-inheritance "CUSTOM_ID")))
      (format "%s-%s" filename_prefix topic))))

(defun pab/teaching-subnote-p ()
  "Test if headline at point is a sub-note."

  (save-excursion
    (org-up-heading-safe)
    (pab/teaching-note-p)))

(defun pab/teaching-note-p ()
  "Test if headline at point is a note."

  (member "notes" (org-get-tags nil t)))

(defun pab/teaching-lecture-p ()
  "Test if headline at point is a lecture."

  (member "lecture" (org-get-tags nil t)))

(defun pab/teaching-problem-p ()
  "Test if headline at point is a problem."

  (member "problems" (org-get-tags nil t)))

(defun pab/teaching-challenge-p ()
  "Test if headline at point is a challenge."

  (member "challenge" (org-get-tags nil t)))

(defun pab/teaching-export-subnote (&optional filename)
  "Export sub-topics.

Saves to FILENAME if passed, otherwise let org decide the filename."

  (if (pab/teaching-subnote-p)
      (let ((export-filename (pab/teaching-export-subtopic-file-name filename)))
	(pab/teaching-export-to-backend '(html) export-filename))
    (message "Not a subnote")))

(defun pab/teaching-get-notes-topics ()
  "Get list of topics under current note."

  (if (pab/teaching-note-p)
      (let ((org-use-tag-inheritance nil))
	(org-map-entries
	 (lambda ()
	   (format "\"%s\"" (org-entry-get nil "CUSTOM_ID")))
	 "+notes-noexport" 'tree))
    (message "Not a note")))

(defun pab/teaching-export-note (&optional filename)
  "Export a note.

Saves to FILENAME if passed, otherwise let org decide the filename."

  (if (pab/teaching-note-p)
      (let ((note-level (org-element-property :level (org-element-at-point))))
	(pab/teaching-export-to-backend '(latex html) filename)
	(org-map-entries
	 (lambda() (pab/teaching-export-subnote filename)) (format "LEVEL=%d" (+ note-level 1)) 'tree))
    (message "Not a note")))

(defun pab/teaching-export-lecture (&optional filename)
  "Export a lecture.

Saves to FILENAME if passed, otherwise let org decide the filename."

  (if (pab/teaching-lecture-p)
	(pab/teaching-export-to-backend '(html) filename)
    (message "Not a lecture")))

(defun pab/teaching-export-problems (&optional filename)
  "Export problems.

Saves to FILENAME if passed, otherwise let org decide the filename."

  (if (pab/teaching-problem-p)
      (pab/teaching-export-to-backend '(html latex) filename)
    (message "Not a problem")))

(defun pab/teaching-export-challenge (&optional filename)
  "Export challenge.

Saves to FILENAME if passed, otherwise let org decide the filename."

  (if (pab/teaching-challenge-p)
	(pab/teaching-export-to-backend '(html latex) filename)
    (message "Not a challenge")))

(defun pab/teaching-export ()
  "Export headline based on tag.

Possible tags are 'notes', 'lecture', 'problems', 'challenge'"

  (interactive)
  (let ((filename (pab/teaching-export-file-name)))
    (cond ((pab/teaching-note-p)
	   (pab/teaching-export-note (format "notes_%s" filename)))
	  ((pab/teaching-subnote-p)
	   (pab/teaching-export-subnote (format "notes_%s" filename)))
	  ((pab/teaching-lecture-p)
	   (pab/teaching-export-lecture (format "lecture_%s" filename)))
	  ((pab/teaching-problem-p)
	   (pab/teaching-export-problems (format "problems_%s"filename)))
	  ((pab/teaching-challenge-p)
	   (pab/teaching-export-challenge (format "challenge_%s"filename)))
	  ('t (message "Can't export from here")))))

(defun pab/teaching-export-all ()
  "Export all notes, lectures and problems/challenges."

  (interactive)
  (let ((org-use-tag-inheritance nil))
    (org-map-entries #'pab/teaching-export "+notes-noexport|+lecture-noexport|+problems-noexport|+challenge-noexport")))

(defvar pab/teaching-mode-map (make-sparse-keymap))
(define-key pab/teaching-mode-map (kbd "C-c e") #'pab/teaching-export)
(define-key pab/teaching-mode-map (kbd "C-c x") #'pab/teaching-export-all)
(define-key pab/teaching-mode-map (kbd "C-c h") (lambda () (pab/teaching-export-to-backend 'html)))
(define-key pab/teaching-mode-map (kbd "C-c t") (lambda () (pab/teaching-export-to-backend 'latex)))

(define-minor-mode pab/teaching-mode
  "Minor mode for my teaching setup.

Loads key-maps and loads settings."

  :init-value nil
  :lighter " pab/teaching"

  (pab/teaching-load-settings)
  (pab/teaching-create-build))
