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

Pareto tries to keep implementation simple and readable by reusing as many code
as possible and providing excessive comments.

.. _LEM: https://github.com/cxxxr/lem
.. _Lispy: https://github.com/abo-abo/lispy