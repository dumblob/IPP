#!/usr/bin/env python3

#MKA:xpacne00

import os
import sys
from operator import itemgetter

err = {
  'arg':       1,   # arguments
  'f_in':      2,   # input file (ro)
  'f_out':     3,   # output file (rw)
  'f_syn':     60,  # input file syntax
  'f_sem':     61,  # input file semantics
  'f_no_wsfa': 62,  # input file does not contain WSFA (well-specified FA)
  'misc':      100  # other error
}

arg = {
  'fd_in':  None,
  'fd_out': None,
  'f':      None,
  'm':      None,
  'i':      None,
}

E_MSG_SYN = 'FSM bad syntax.'

def err_exit (msg = 'Unknow error occured.', e = err['misc']):
  print(msg, 'Use --help for help.', file = sys.stderr)
  sys.exit(e)  # clean everything including file handles etc.

for p in sys.argv[1:]:
  if p == '--help':
    if len(sys.argv) != 2:
      err_exit('Argument mismatch.', err['arg'])
    print(
"""--help
    this help
--input=filename
    UTF-8 input file; if ommited, stdin is used
--output=filename
    UTF-8 output file path; if the file exists, it will be overwritten;
    if ommited, stdout is used
-f --find-non-finishing
    validate input FSM for WSFA
    can't be used in conjunction with -m (--minimize)
-m --minimize
    WSFA minimalization
    can't be used in conjunction with -f (--find-non-finishing)
-i --case-insensitive
    be case insensitive; default: be case sensitive
""")
    sys.exit(0)

  if p in ('-f', '--find-non-finishing'):
    arg['f'] = True
  elif p in ('-m', '--minimize'):
    arg['m'] = True
  elif p in ('-i', '--case-insensitive'):
    arg['i'] = True
  else:
    a, b, c = p.partition('=')

    if a == '--input' and c != '':
      try:
        arg['fd_in'] = open(c, 'r')
      except:  # catch all exceptions
        err_exit('Error while openin input file.', err['f_in'])
      continue

    if a == '--output' and c != '':
      try:
        arg['fd_out'] = open(c, 'w')
      except:  # catch all exceptions
        err_exit('Error while openin output file.', err['f_out'])
      continue

    err_exit('Unknown argument "' + p + '".', err['arg'])

# check argument compatibility
if arg['m'] and arg['f']:
  err_exit('Mutual exclusion of -f and -m arguments broken.', err['arg'])

if arg['fd_in']  is None: arg['fd_in']  = sys.stdin
if arg['fd_out'] is None: arg['fd_out'] = sys.stderr

# read the whole input into memory (in our case it is not as bad idea)
try:
  input_str = arg['fd_in'].read()  # translate \r \n\r to \n
except:
  err_exit('Error occured while reading input file.', err['f_in'])

# not needed any more
arg['fd_in'].close();

# handle case sensitivity
if arg['i']:
  input_str = input_str.lower()

# lex states enum
class lex_state:
  class init:               pass
  class identifier_quote_0: pass  # '
  class identifier_quote_1: pass  # '''' 'abc' 'a''b''c'
  class identifier:         pass  # [a-zA-Z] [0-9a-zA-Z_]
  class minus:              pass  # -
  class hashkey:            pass  # #

# lex return values enum
class lex_token:
  class string:          pass  # ab1
  class l_parenthesis:   pass  # (
  class r_parenthesis:   pass  # )
  class l_curly_bracket: pass  # {
  class r_curly_bracket: pass  # }
  class comma:           pass  # ,
  class rewrite:         pass  # ->
  class eof:             pass  # ->

def get_token(tok_type):
  if tok_type == 'fsm_symbol':
    a, b = lex_symbol()
  else:
    a, b = lex_c()
  # handle case sensitivity
  if arg['i']:
    return a.lower(), b
  else:
    return a, b

# index to the input string
index = 0

# input FSM state parser
def lex_symbol():
  state = lex_state.init
  output = ''  # output string
  global index

  while True:
    if index >= len(input_str):
      return '', lex_token.eof  # whole string was read
    else:
      c = input_str[index]
      index += 1

    if state == lex_state.init:
      if c.isspace():
        continue
      elif c == '\'':
        state = lex_state.identifier_quote_0
      elif c not in ('(', ')', '{', '}', '-', '>', ',', '.', '|', '#',
          ' ', '\t', '\n', '\r'):
        return c, lex_token.string
      else:
        return '', None  # fail

    # lex_state.identifier_quote_0
    else:
      # look in the future for 2 chars [''']
      if c + input_str[index:index +1] == '\'\'\'':
        index += 2
        return '\'', lex_token.string
      # look in the future for 1 char [a']
      elif c != '\'' and input_str[index] == '\'':
        index += 1
        return c, lex_token.string
      # it is epsilon [']
      elif c == '\'':
        return '', lex_token.string
      else:
        return '', None  # fail

# input parser
def lex_c():
  state = lex_state.init
  output = ''  # output string
  global index

  while True:
    if index >= len(input_str):
      return '', lex_token.eof  # whole string was read
    else:
      c = input_str[index]
      index += 1

    if state == lex_state.init:
      if c.isspace():
        continue
      elif c == '#':
        state = lex_state.hashkey
      elif c == '(':
        return c, lex_token.l_parenthesis
      elif c == ')':
        return c, lex_token.r_parenthesis
      elif c == '{':
        return c, lex_token.l_curly_bracket
      elif c == '}':
        return c, lex_token.r_curly_bracket
      elif c == '-':
        state = lex_state.minus
      elif c == ',':
        return c, lex_token.comma
      # C identifier [a-zA-Z]; can't start with [^_0-9]
      elif c != '_' and ('a' <= c <= 'z' or 'A' <= c <= 'Z') and not c.isdigit():
        output = c
        state = lex_state.identifier
      else:
        return '', None  # fail

    elif state == lex_state.identifier:
      # C identifier [a-zA-Z]; can contain [_0-9]
      if c == '_' or 'a' <= c <= 'z' or 'A' <= c <= 'Z' or c.isdigit():
        output += c
      # end of identifier found
      else:
        # read this char once again in the next get_token call
        index -= 1
        # identifier can't end with underscore
        if output[-1:] == '_':
          return '', None  # fail
        else:
          return output, lex_token.string

    # read to EOL or EOF
    elif state == lex_state.hashkey:
      if c == '\n':
        state = lex_state.init

    elif state == lex_state.minus:
      if c == '>':
        return c, lex_token.rewrite
      else:
        return '', None  # fail

# FSM structures
fsm_states      = set()
fsm_alphabet    = set()
fsm_rules       = {}  # 'state': [{'symbol0': value}, 'symbol1', ...]
fsm_start_state = ''
fsm_end_states  = set()

# FSM syntax
a, b = get_token('c')
if b != lex_token.l_parenthesis: err_exit(E_MSG_SYN, err['f_syn'])

# finite set of states
a, b = get_token('c')
if b != lex_token.l_curly_bracket: err_exit(E_MSG_SYN, err['f_syn'])
while True:
  a, b = get_token('c')
  if b != lex_token.string: break
  fsm_states.add(a)

  a, b = get_token('c')
  if b != lex_token.comma: break
if b != lex_token.r_curly_bracket: err_exit(E_MSG_SYN, err['f_syn'])
a, b = get_token('c')
if b != lex_token.comma: err_exit(E_MSG_SYN, err['f_syn'])

# non-empty input alphabet
a, b = get_token('c')
if b != lex_token.l_curly_bracket: err_exit(E_MSG_SYN, err['f_syn'])
while True:
  tmp = index
  a, b = get_token('fsm_symbol')
  if b != lex_token.string:
    index = tmp
    a, b = get_token('c')  # re-read as identifier
    break
  fsm_alphabet.add(a)

  a, b = get_token('c')
  if b != lex_token.comma: break
if b != lex_token.r_curly_bracket: err_exit(E_MSG_SYN, err['f_syn'])
a, b = get_token('c')
if b != lex_token.comma: err_exit(E_MSG_SYN, err['f_syn'])

# set of rules
a, b = get_token('c')
if b != lex_token.l_curly_bracket: err_exit(E_MSG_SYN, err['f_syn'])
while True:
  tmp = index
  x, y = get_token('c')
  if y != lex_token.string:
    index = tmp  # re-read the last token
    break

  tmp = index
  j, k = get_token('fsm_symbol')
  # parse it once again as ->
  if k != lex_token.string:
    index = tmp
    j = ''  # epsilon

  a, b = get_token('c')
  if b != lex_token.rewrite: err_exit(E_MSG_SYN, err['f_syn'])

  a, b = get_token('c')
  if b != lex_token.string: err_exit(E_MSG_SYN, err['f_syn'])

  # presence control
  if x not in fsm_states or j not in fsm_alphabet or a not in fsm_states:
    err_exit('Unknown state or symbol in ruleset.', err['f_sem'])

  if x in fsm_rules:
    for tmp in fsm_rules[x]:  # tmp == dict
      if j in tmp and tmp[j] != a:
        err_exit('Non-deterministic FSM given.', err['f_no_wsfa'])
    fsm_rules[x].append({j: a})  # add new transition
  else:
    fsm_rules[x] = [{j: a}]  # create new transition

  a, b = get_token('c')
  if b != lex_token.comma: break
if b != lex_token.r_curly_bracket: err_exit(E_MSG_SYN, err['f_syn'])
a, b = get_token('c')
if b != lex_token.comma: err_exit(E_MSG_SYN, err['f_syn'])

# start state
a, b = get_token('c')
if b != lex_token.string: err_exit(E_MSG_SYN, err['f_syn'])
fsm_start_state = a
a, b = get_token('c')
if b != lex_token.comma: err_exit(E_MSG_SYN, err['f_syn'])

# set of end states
a, b = get_token('c')
if b != lex_token.l_curly_bracket: err_exit(E_MSG_SYN, err['f_syn'])
while True:
  a, b = get_token('c')
  if b != lex_token.string: break
  fsm_end_states.add(a)

  a, b = get_token('c')
  if b != lex_token.comma: break
if b != lex_token.r_curly_bracket: err_exit(E_MSG_SYN, err['f_syn'])
a, b = get_token('c')
if b != lex_token.r_parenthesis: err_exit(E_MSG_SYN, err['f_syn'])
a, b = get_token('c')
if b != lex_token.eof: err_exit(E_MSG_SYN, err['f_syn'])

# check semantics of the given FSM
if not fsm_alphabet:
  err_exit('Input alphabet empty.', err['f_sem'])
if fsm_states.intersection(fsm_alphabet):
  err_exit('Input states and alphabet are not disjoint.', err['f_sem'])
if fsm_start_state not in fsm_states:
  err_exit('Start state is not present in input states.', err['f_sem'])
if not fsm_end_states.issubset(fsm_states):
  err_exit('End states are not subset of input states.', err['f_sem'])

########################  proving for WSFA  ########################

# set of transitions in the reverse order without symbols
fsm_rules_reverse = {}  # 'state': set([state0, state1, ...])
# epsilon search + building of the reverse rules list
for x in fsm_rules:       # x == key: list
  for y in fsm_rules[x]:  # y == dict
    for z in y:           # z == key (symbol)
      if z == '':
        err_exit('Non-WSFA given (epsilon rule found).', err['f_no_wsfa'])
      # y[z] == state "to"; x == state "from"
      if y[z] in fsm_rules_reverse:
        fsm_rules_reverse[y[z]].add(x)
      else:
        fsm_rules_reverse[y[z]] = set([x])

# mode == True for nonterminating search; otherwise start state search
def bfs(rules, mode):
  states_entered = []
  generated_nodes = []
  term_state = None  # terminating state for mode "nonterminating search"

  global fsm_end_states
  global fsm_start_state
  global err

  # inaccessible state search (Bredth First Search)
  for x in rules:  # x == dict
    states_entered = []
    generated_nodes = [x]
    for y in generated_nodes:
      if mode == True:
        # current state is terminating
        if y in fsm_end_states:
          break;
      else:
        # current state is accessible => continue searching
        if y == fsm_start_state:
          break
      # expand this node
      for z in rules[y]:
        # if we was not previously there
        if z not in states_entered:
          states_entered.append(z)
          # make sure, it will be tested (according to mode)
          generated_nodes.append(z)
    else:
      if mode == True:
        # first found and last allowed nonterminating state
        if term_state is None:
          term_state = x
        else:
          err_exit('Non-WSFA given (1+ nonterminating states present).',
              err['f_no_wsfa'])
      else:
        # whole graph/FA traversed, but no path to this node/state was found
        err_exit('Non-WSFA given (inaccessible state present).',
            err['f_no_wsfa'])
  if mode == True:
    return term_state

# state accessibility
bfs(fsm_rules_reverse, False)

# flip over the rules to be in the original direction
fsm_rules_reverse_reverse = {}
for x in fsm_rules_reverse:            # x == state "to" from rules
  for y in fsm_rules_reverse[x]:       # y == state "from" from rules
    if y in fsm_rules_reverse_reverse:
      fsm_rules_reverse_reverse[y].add(x)
    else:
      fsm_rules_reverse_reverse[y] = set([x])
# at most 1 nonterminating state
term_state = bfs(fsm_rules_reverse_reverse, True)

# find all missing rules (prove completness of DFA => cannot get stuck)
for x in fsm_states:        # x == list_value
  for z in fsm_alphabet:    # z == list_value
    for y in fsm_rules[x]:  # y == dict
      if z in y:
        break
    else:
      # symbol not found => fail
      break
  else:
    continue
  err_exit('Non-WSFA given (DFA is incomplete, can get stuck).',
      err['f_no_wsfa'])

########################  WSFA proved  ########################

# print() wrapper
def printw(*abc, **xyz):
  global arg
  xyz['file'] = arg['fd_out']
  xyz['end'] = ''
  print(*abc, **xyz)

# handle -f argument
if arg['f']:
  if term_state: printw(term_state)
  sys.exit()

# output FSM structures
out_fsm_states      = set()
out_fsm_alphabet    = set()
out_fsm_rules       = {}  # 'state': [{'symbol0': value}, 'symbol1', ...]
out_fsm_start_state = ''
out_fsm_end_states  = set()

# minimalization
if arg['m']:
  # [[state0, state1], [state2, state3, state4], ...]
  all_states = [list(fsm_end_states), list(fsm_states.difference(fsm_end_states))]

  # if the set/list is not divisible by this symbol, after any division
  #   by other symbol this could not get divisible again => loop only
  #   once for each symbol
  for symbol in fsm_alphabet:
    all_states_tmp = []

    # while not empty
    while all_states:
      sub_list = all_states[0]
      evidence = []
      r_state = ''

      # make evidence for each item in sub_list, into which sub-list
      #   can I get with it
      for x in sub_list:
        # get the state "to" from the right side of the rule for {x symbol -> ???}
        for a in fsm_rules[x]:
          if symbol in a:
            r_state = a[symbol]
            break
        # don't be afraid, each pair (state + symbol) points only to 1 sub-list
        for i, y in enumerate(all_states):
          if r_state in y:
            # save the sub-list index
            evidence.append(i)

      if not evidence:
        # these are not divisible by this symbol
        all_states_tmp.append(all_states.pop(0))
        continue

      # does it contain only 1 value?
      tmp = evidence[0]
      for xyz in evidence[1:]:
        if tmp != xyz: break
      else:
        # these are not divisible by this symbol
        all_states_tmp.append(all_states.pop(0))
        continue

      # while not empty
      while evidence:
        first = evidence.pop(0)
        final_sub_list = [sub_list.pop(0)]

        # try hard to find all rows containing this value and separate them
        while True:
          try:
            # search for the first occurance of current sub_list index
            i = evidence.index(first)
            # remove found item from evidence
            evidence.pop(i)
            # remove corresponding value from sub_list and add this item to
            #   the final sub_list
            final_sub_list.append(sub_list.pop(i))
          except:
            break
        # save our new "sub-list"
        all_states.append(final_sub_list)

      # remove this sub_list, because it is yet processed
      all_states.pop(0)
    # new all_states
    all_states = all_states_tmp

  tmp_rules = {}  # 'state': [{'symbol0': value}, 'symbol1', ...]
  # traverse all rules and create new ones
  for a in fsm_rules:       # a == key (id left)
    for b in fsm_rules[a]:  # b == dict
      for c in b:           # c == key (symbol)
        # find index of sub_list containing rule left id
        for i, d in enumerate(all_states):
          if a in d:
            break  # found
        # find index of sub_list containing rule right id
        for j, d in enumerate(all_states):
          if b[c] in d:
            break  # found
        if i in tmp_rules:
          tmp_rules[i].append( {c: j} )
        else:
          tmp_rules[i] = [ {c: j} ]

  # find the sub_list index containing the start state
  for i, a in enumerate(all_states):
    if fsm_start_state in a:
      out_fsm_start_state = i

  tmp_end_states = set()
  # end states
  for i, a in enumerate(all_states):
    if fsm_end_states.intersection(set(a)):
      tmp_end_states.add(i)

  tmp_fsm_states = []
  # names normalization
  for a in all_states:
    tmp_fsm_states.append('_'.join(sorted(a)))


  ############  translate indexes to strings  ############


  # alphabet (no change needed)
  out_fsm_alphabet = fsm_alphabet

  # rules
  for a in tmp_rules:       # a == key (id left)
    for b in tmp_rules[a]:  # b == dict
      for c in b:           # c == key (symbol)
        if tmp_fsm_states[a] in out_fsm_rules:
          out_fsm_rules[tmp_fsm_states[a]].append( {c: tmp_fsm_states[b[c]]} )
        else:
          out_fsm_rules[tmp_fsm_states[a]] = [ {c: tmp_fsm_states[ b[c] ]} ]

  # start state
  out_fsm_start_state = tmp_fsm_states[out_fsm_start_state]

  # end states
  for a in tmp_end_states:
    out_fsm_end_states.add(tmp_fsm_states[a])

  # start states
  out_fsm_states = set(tmp_fsm_states)
else:
  out_fsm_states      = fsm_states
  out_fsm_alphabet    = fsm_alphabet
  out_fsm_rules       = fsm_rules
  out_fsm_start_state = fsm_start_state
  out_fsm_end_states  = fsm_end_states

# normalization
printw('(\n{')  # states
printw(', '.join(sorted(out_fsm_states)))
printw('},\n{')  # alphabet
printw('\'' + '\', \''.join(sorted(out_fsm_alphabet)) + '\'')
printw('},\n{\n')  # rules
# transformation into 1 big list
array3 = []
for x in out_fsm_rules:            # x    == key (id left)
  for y in out_fsm_rules[x]:       # y    == dict
    for z in y:                    # z    == key (symbol)
      array3.append([x, z, y[z]])  # y[z] == value (id right)
printw(',\n'.join([ x[0] + ' \'' + x[1] + '\' -> ' + x[2]
    for x in sorted(array3, key=itemgetter(0, 1, 2)) ]))
printw('\n},\n'+out_fsm_start_state+',\n{')  # start state + end states
printw(', '.join(sorted(out_fsm_end_states)))
printw('}\n)\n')

