query:
    select | update | delete | insert ;

my_field_int:
    `TABLE_ID` | `POS` | `MTYPE` | `PRTYPE` | `LEN` ;

my_field_char:
    `NAME` ;

my_field:
    my_field_int | my_field_char ;

my_table:
    { 'Tablei' . $prng->int(1,450000) }
;

insert:
    INSERT INTO my_table ( my_field_int ) VALUES ( _tinyint_unsigned ) |
    INSERT INTO my_table ( my_field_char ) VALUES ( _string )
;

update:
    UPDATE my_table SET my_field_char = _string ORDER BY RAND() LIMIT 1 | 
    UPDATE my_table SET my_field_int = _tinyint_unsigned ORDER BY RAND() LIMIT 1 
;

delete:
    DELETE FROM my_table LIMIT 1 ;

select:
    SELECT my_field FROM my_table ORDER BY RAND() LIMIT 10 |
    SELECT * FROM my_table
;
