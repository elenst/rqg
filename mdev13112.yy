query:
    UPDATE IGNORE _table SET _field_int_indexed = _field_int_indexed + 1 WHERE _field_pk = _smallint_unsigned |
    UPDATE _table SET _field_char = _string WHERE _field_pk = _smallint_unsigned
;
