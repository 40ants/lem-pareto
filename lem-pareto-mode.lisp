(defpackage :lem-pareto-mode
  (:use #:cl)
  (:export #:*pareto-mode-keymap*
           #:pareto-mode))
(in-package :lem-pareto-mode)


(lem:define-minor-mode pareto-mode
    (:name "pareto"
     :description "Addon to Paredit for easier semantic code editing."
     :keymap *pareto-mode-keymap*))

(defun point ()
  (lem:current-point))

(defun left-p (&key (at (point)))
  "Return t if before a opening paren."
  (lem:looking-at at
                  "[[({]"))

(defun right-p (&key (at (point)))
  "Return t if after a closing paren."
  ;; Here we need to look at the character before the cursor.
  ;; That is why we do character-offset -1
  (lem:with-point ((before-cursor at))
    (lem:character-offset before-cursor -1)
    (lem:looking-at before-cursor
                    "[])}]")))

(defun one-char-left (&key (from (point)))
  (lem:character-offset from -1))

(defun one-char-right (&key (from (point)))
  (lem:character-offset from 1))

(defun up ()
  (lem:backward-up-list))

(defun get-code (label body)
  "A helper for `when-to-sexp' to extract different parts of the code."
  (rest (assoc label body)))

(defmacro when-on-sexp ((&key char-to-insert) &body body)
  "Executes body if current point is before or after the paren.
   Before execution, point is moved to the position before opening paren.
   If point is not on the sexp, than char-to-insert is inserted."
  (let ((right-code (get-code :right body))
        (left-code (get-code :left body)))
    (when (or (and right-code
                   (null left-code))
              (and left-code
                   (null right-code)))
      (error "You should use :left and :right labels together."))
    
    `(progn
       ,(unless right-code
          '(when (right-p)
            (pareto-different)))

       (cond
         ,@(when right-code
             `(((right-p)
                ,@right-code)))
         ((left-p)
          ,@(or left-code body))
         (,char-to-insert
          (lem:insert-character (point)
                                ,char-to-insert))))))

(defmacro when-on-the-right ((&key char-to-insert) &body body)
  "Executes body if current point is after the paren.
   If point is not on the sexp, than char-to-insert is inserted."
  `(cond
    ((right-p)
     ,@body)
    (,char-to-insert
     (lem:insert-character (point)
                           ,char-to-insert))))

(defmacro when-on-the-left ((&key char-to-insert) &body body)
  "Executes body if current point is before of the paren.
   If point is not on the sexp, than char-to-insert is inserted."
  `(cond
     ((left-p)
      ,@body)
     (,char-to-insert
      (lem:insert-character (point)
                            ,char-to-insert))))

(lem:define-command pareto-different () ()
  "Switch to the different side of current sexp."
  (let ((buffer (lem:current-buffer)))
    (cond
      ;; During selection, "d" will move cursor from begining to the end
      ((and (lem:buffer-mark-p buffer)
            (not (lem:point= (lem:region-beginning)
                             (lem:region-end))))
       (lem:exchange-point-mark))
      ;; Moving from the end of sexp to the beginning
      ((right-p)
       (lem:backward-list))
      ;; Moving from the beginning of sexp to the end
      ((left-p)
       (lem:forward-list))
      ;; Just insering the "d"
      (t (lem:insert-character (point) #\d)))))

(lem:define-command pareto-mark-list () ()
  "Mark list from special position."
  (when-on-sexp (:char-to-insert #\m)
    (lem:mark-set)
    (pareto-different)))

(lem:define-command pareto-clone () ()
  "Clone sexp and indent it.
   If it is a top level, then there will be a new line added."
  ;; If we are at the end of sexp,
  ;; we need to go to the beginning first,
  ;; because when we'll make a selection later,
  ;; the point will be moved to the end of the sexp,
  ;; and a copy will be inserted after it.
  (when-on-sexp (:char-to-insert #\c)
    ;; We will add an empty new line, if the sexp begins in the first column.
    (let ((add-extra-new-line (zerop (lem:point-charpos (point)))))
      ;; First, we need to select a sexp
      (pareto-mark-list)
      ;; and then to copy it as a region:
      (let ((text (lem:points-to-string (lem:region-beginning)
                                        (lem:region-end))))
        (lem:newline)
        
        (when add-extra-new-line
          (lem:newline))
        
        (lem:insert-string (point)
                           text)
        ;; at the end, we are indenting it nicely.
        ;; To do indentation correctly, we need
        ;; to move to the beginning and to indent the first
        ;; line, to make it in peace with the outer code.
        (pareto-different)
        (lem:indent-line (point))
        ;; Then move to the end and indent the whole new sexp.
        (pareto-different)
        (lem-lisp-mode:lisp-indent-sexp)))))

(lem:define-command pareto-kill () ()
  "Kills sexp and moves point to the next sexp."
  (lem-paredit-mode:paredit-kill)
  ;; We need to indent a line because
  ;; paredit kill leaves it with a bad indentation
  ;; and cursor does not point to the next sexp.
  (lem-lisp-mode:lisp-indent-sexp))

(lem:define-command pareto-raise () ()
  "Replaces the parent with the current sexp."
  (when-on-sexp (:char-to-insert #\r)
    ;; Killing a current sexp and remembering it in the
    ;; *kill-ring*
    (pareto-kill)
    (lem:backward-up-list)
    ;; Now, removing outer sexp to replace it with the raised one.
    ;; Here we need to override a *kill-ring* to prevent
    ;; outer sexp to be pushed to it.
    (let ((lem::*kill-ring* nil)
          (lem::*kill-new-flag* t)
          (lem::*enable-clipboard-p* nil)
          (lem::*kill-ring-yank-ptr* nil))
      (pareto-kill))
    (lem:yank)
    (lem-lisp-mode:lisp-indent-sexp)))

(defun search-last-sexp ()
  "Returns a point pointing to the closing paren of the last sibling sexp."
  (lem:with-point ((prev-point (point)))
    (loop for point = prev-point then (lem:scan-lists prev-point 1 0 t)
          unless point
            do (return prev-point))))

(lem:define-command pareto-raise-some () ()
  "Replaces the parent with a current sexp and all children sexps after it."
  (when-on-sexp (:char-to-insert #\R)
    ;; When we enter the `when-on-sexp', we are on the left side,
    ;; so, we need to remember the current point to go to the last sexp.
    (let ((beginning (point))
          (end (search-last-sexp)))
      (lem:kill-region beginning end)

      (lem:backward-up-list)
      ;; Now, removing outer sexp to replace it with the raised one.
      ;; Here we need to override a *kill-ring* to prevent
      ;; outer sexp to be pushed to it.
      (let ((lem::*kill-ring* nil)
            (lem::*kill-new-flag* t)
            (lem::*enable-clipboard-p* nil)
            (lem::*kill-ring-yank-ptr* nil))
        (pareto-kill))
      ;; Now inserting children back to the buffer.
      (lem:yank)
      ;; And to indent whole parent sexp to make every line fit it place.
      ;; This trick does not work if sexps were extracted to the top level.
      (lem:save-excursion
        (lem:backward-up-list)
        (lem-lisp-mode:lisp-indent-sexp)))))

(lem:define-command pareto-shift-right () ()
  "Moves a right paren to the right."
  (when-on-sexp (:char-to-insert #\>)
    (one-char-right)
    (lem-paredit-mode:paredit-slurp)
    (up)
    (pareto-different)))

(lem:define-command pareto-shift-left () ()
  "Moves a right paren to the left."
  (when-on-sexp (:char-to-insert #\<)
    (one-char-right)
    (lem-paredit-mode:paredit-barf)
    (up)
    (pareto-different)))

(lem:define-command pareto-next-sexp () ()
  "Moves a the next sexp on the same level."
  (when-on-sexp (:char-to-insert #\j)
    (:left
     ;; In case of the left paren, we a jumping forward through
     ;; two parens (closing and opening) and return back to the
     ;; opening one.
     (lem:scan-lists (point) 2 0)
     (pareto-different))
    (:right
     ;; From right parens just jumping to the next one
     (lem:scan-lists (point) 1 0))))

(lem:define-command pareto-prev-sexp () ()
  "Moves a the next sexp on the same level."
  (when-on-sexp (:char-to-insert #\k)
    (:right
     ;; In case of the right paren, we a jumping backward through
     ;; two parens (opening and closing) and return back to the
     ;; closing one.
     (lem:scan-lists (point) -2 0)
     (pareto-different))
    (:left
     ;; From left paren just jumping to the next one
     (lem:scan-lists (point) -1 0))))

(lem:define-command pareto-newline () ()
  "Adds a new line and indents it."
  (lem:newline)
  (lem:indent-line (point)))

(lem:define-command pareto-insert-paren () ()
  "Inserts a new pair of parens.
   By default, it acts like similar function from the Paredit,
   but if there is an active selection, then it surrounds it
   with parens. In this case, new place of the cursor depends
   on the text surrounded by new parens.

   If selected text is a sexp, then cursor is placed before it
   and separated by space.
   Otherwise, cursor is placed behind it without any space, because
   most probably, you want to make a function call and it may be
   called without arguments."
  (let ((buffer (lem:current-buffer)))
    (cond
      ;; When selection is active, we want to surround it
      ;; with parens
      ((lem:buffer-mark-p buffer)
       (let ((on-sexp (left-p :at (lem:region-beginning))))
         (when on-sexp
           (lem:insert-character (lem:region-beginning) #\Space))
         (lem:insert-character (lem:region-beginning) #\()

         (lem:insert-character (lem:region-end) #\))
         ;; Also we want to put the cursor right after the opening paren
         ;; or before the closing paren, depending on the code we are
         ;; surrounding.
         (lem:move-point (lem:current-point)
                         (if on-sexp
                             (one-char-right :from
                                             (lem:region-beginning))
                             (one-char-left :from
                                            (lem:region-end))))))
      (t
       (lem-paredit-mode:paredit-insert-paren)))))

(lem:define-command pareto-mark-symbol () ()
  "Marks current symbol"
  ;; When cursor is on the left paren, we want to select
  ;; the first symbol in a sexp
  (do ()
      ((not (left-p :at (point))))
    (log:info "Skipping (")
    (lem:character-offset (point) 2))

  (lem:skip-symbol-backward (point))
  (lem:mark-set)
  (lem:skip-symbol-forward (point)))

(lem:define-key *pareto-mode-keymap* "d" 'pareto-different)
(lem:define-key *pareto-mode-keymap* "m" 'pareto-mark-list)
(lem:define-key *pareto-mode-keymap* "M-m" 'pareto-mark-symbol)
(lem:define-key *pareto-mode-keymap* "c" 'pareto-clone)
(lem:define-key *pareto-mode-keymap* "r" 'pareto-raise)
(lem:define-key *pareto-mode-keymap* "R" 'pareto-raise-some)
(lem:define-key *pareto-mode-keymap* "C-k" 'pareto-kill)
(lem:define-key *pareto-mode-keymap* ">" 'pareto-shift-right)
(lem:define-key *pareto-mode-keymap* "<" 'pareto-shift-left)
(lem:define-key *pareto-mode-keymap* "j" 'pareto-next-sexp)
(lem:define-key *pareto-mode-keymap* "k" 'pareto-prev-sexp)
(lem:define-key *pareto-mode-keymap* "Return" 'pareto-newline)
(lem:define-key *pareto-mode-keymap* "(" 'pareto-insert-paren)

;; TODO: replace with custom implementation which will delete a word
;;       probably it is a good idea to contribute it to the Paredit
(lem:define-key *pareto-mode-keymap* "C-w" 'lem-paredit-mode:paredit-backward-delete)
