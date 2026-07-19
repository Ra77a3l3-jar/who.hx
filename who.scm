(require "helix/editor.scm")
(require "helix/misc.scm")
(require "helix/components.scm")
(require "helix/static.scm")
(require "helix/ext.scm")
(require (prefix-in helix. "helix/commands.scm"))
(require "notify/notify.scm")

(provide who-toggle
         who-set-color!
         who-set-style!)

(define (who-info msg)
  (notify msg #:title "who.hx"))

(define *who-enabled* #f)
(define *who-hint-id* #f)
(define *who-line* #f)
(define *who-style* #f)

;; falls back to the theme's inlay hint style when no custom style is set
(define (who-hint-style)
  (or *who-style* (theme-scope-ref "ui.virtual.inlay-hint")))

(define (who-hex-byte hex start)
  (string->number (substring hex start (+ start 2)) 16))

;;@doc
;; Set the blame hint color from a "#rrggbb" hex string
(define (who-set-color! hex)
  (set! *who-style*
        (style-fg (theme-scope-ref "ui.text")
                  (Color/rgb (who-hex-byte hex 1)
                             (who-hex-byte hex 3)
                             (who-hex-byte hex 5)))))

;;@doc
;; Set the full Style used for the blame hint
(define (who-set-style! style)
  (set! *who-style* style))

(define (who-git-repo? dir)
  (let ([proc (~> (command "git" (list "-C" dir "rev-parse" "--is-inside-work-tree"))
                  with-stdout-piped
                  with-stderr-piped
                  spawn-process)])
    (and (Ok? proc)
         (string=? (trim (read-port-to-string (child-stdout (Ok->value proc)))) "true"))))

(define (who-git-repo-root dir)
  (let ([proc (~> (command "git" (list "-C" dir "rev-parse" "--show-toplevel"))
                  with-stdout-piped
                  with-stderr-piped
                  spawn-process)])
    (if (Ok? proc)
        (trim (read-port-to-string (child-stdout (Ok->value proc))))
        dir)))

;; blames line by line instead of doing the complte file
(define (who-blame-line-hash root path line)
  (define line-str (int->string line))
  (let ([proc (~> (command "git"
                          (list "-C"
                               root
                               "blame"
                               "--porcelain"
                               "-L"
                               (string-append line-str "," line-str)
                               "--"
                               path))
                  with-stdout-piped
                  with-stderr-piped
                  spawn-process)])
    (if (Ok? proc)
        (let ([lines (filter (lambda (l) (> (string-length l) 0))
                             (split-many (read-port-to-string (child-stdout (Ok->value proc))) "\n"))])
          (if (null? lines) #f (car (split-many (car lines) " "))))
        #f)))

(define (who-commit-summary root sha)
  (let ([proc (~> (command "git" (list "-C" root "show" "-s" "--format=%h %an, %ar: %s" sha))
                  with-stdout-piped
                  with-stderr-piped
                  spawn-process)])
    (if (Ok? proc)
        (trim (read-port-to-string (child-stdout (Ok->value proc))))
        #f)))

(define (who-blame-hint root path line)
  (define sha (who-blame-line-hash root path line))
  (cond
    [(not sha) #f]
    [(equal? sha "0000000000000000000000000000000000000000") "  uncommitted"]
    [else
     (define summary (who-commit-summary root sha))
     (and summary (string-append "  " summary))]))

(define (who-clear-hint!)
  (when *who-hint-id*
    (remove-inlay-hint-by-id (list-ref *who-hint-id* 0) (list-ref *who-hint-id* 1))
    (set! *who-hint-id* #f)))

;; runs on a background thread so doesn slow the editor
(define (who-update!)
  (define path (cx->current-file))
  ;; use the file's directory so blame works no matter where hx was launched from
  (define dir (and path (parent-name path)))
  (cond
    [(not *who-enabled*) (who-clear-hint!)]
    [(not path) (who-clear-hint!)]
    [(not (who-git-repo? dir)) (who-clear-hint!)]
    [else
     (define line (+ (get-current-line-number) 1))
     (unless (equal? line *who-line*)
       (set! *who-line* line)
       (who-clear-hint!)
       (spawn-native-thread
        (lambda ()
          (define root (who-git-repo-root dir))
          (define hint (who-blame-hint root path line))
          (hx.with-context
           (lambda ()
             ;; only apply if the cursor is still on this line
             (when (and hint (equal? line *who-line*))
               ;; line is 1 indexed, the hint API takes 0 indexed lines
               (set! *who-hint-id*
                     (add-styled-line-inlay-hint (- line 1)
                                                 'end
                                                 (list (list hint (who-hint-style)))))
               (helix.redraw)))))))]))

(register-hook 'selection-did-change (lambda (_view-id) (enqueue-thread-local-callback who-update!)))

(register-hook 'document-changed
               (lambda (_doc-id _old-text)
                 (set! *who-line* #f)
                 (enqueue-thread-local-callback who-update!)))

(register-hook 'document-opened
               (lambda (_doc-id)
                 (set! *who-line* #f)
                 (enqueue-thread-local-callback who-update!)))

;;@doc
;; Toggle the git blame hint for the current line
(define (who-toggle)
  (set! *who-enabled* (not *who-enabled*))
  (if *who-enabled*
      (begin
        (set! *who-line* #f)
        (enqueue-thread-local-callback who-update!)
        (who-info "blame hints enabled"))
      (begin
        (who-clear-hint!)
        (who-info "blame hints disabled"))))

;; deferred so the currently open buffer gets an initial hint
(enqueue-thread-local-callback who-update!)
