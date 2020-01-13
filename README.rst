=============================================================
 Pareto - LEM mode to make Lisp code editing more efficient!
=============================================================

Pareto is an additional minor mode, supplement to the Paredit,
built into the `LEM`_.

The main idea was taken from `Lispy`_ mode for Emacs. Whereas Lispy
is a separate mode, Pareto reuses some Paredit functionality, and
both minor modes should be enabled.

The idea
========

The idea, inherited from the Lispy is to use short one letter (vi style)
binding to navigate and edit sexps. Most bindings manipulate with the
"current sexp". Current sexp is a sexp right before the cursor or right after the
cursor.

Pareto implements only most commonly used functionality of the Lispy:

* ``m`` - marks the current sexp.
* ``c`` - copies current sexp.
* ``Ctrl-k`` - kills current sexp and moves point to the next one.
* ``r`` - raises current sexp.
* ``R`` - raises current sexp and all following siblings.
* ``<`` - moves right paren to the left (aka barf).
* ``>`` - moves right paren to the right (aka slurp).
* ``j`` - jumps to the next sibling sexp.
* ``k`` - jumps to the previous sibling sexp.
* ``Return`` - autoindents a new line (this is not from Lispy, but also nice to have feature).
* ``(`` - does the same like Paredit, but additionally can surround selected region.

Pareto tries to keep implementation simple and readable by reusing as many code
as possible and providing excessive comments.

Installation
============

1. Clone the repository https://github.com/40ants/lem-pareto to some directory:

   .. code:: bash

      mkdir -p ~/projects/lisp/
      cd ~/projects/lisp/
      git clone https://github.com/40ants/lem-pareto

2. Add this initialization code to your ``~/.lem/init.lisp``:

   .. code:: lisp

      (in-package :lem-user)

      (push "~/projects/lisp/lem-pareto/" asdf:*central-registry*)
      (asdf:load-system :lem-pareto)
      ;; Enable Paredit and Pareto along with Lisp mode
      (add-hook *find-file-hook*
                (lambda (buffer)
                  (when (eq (buffer-major-mode buffer)
                            'lem-lisp-mode:lisp-mode)
                    (change-buffer-mode buffer 'lem-paredit-mode:paredit-mode t)
                    (change-buffer-mode buffer 'lem-pareto-mode:pareto-mode t))))

.. _LEM: https://github.com/cxxxr/lem
.. _Lispy: https://github.com/abo-abo/lispy
