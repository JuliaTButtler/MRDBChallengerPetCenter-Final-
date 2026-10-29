-- Tabelas Criadas:
-- 1. USERS

CREATE TABLE users (
    id NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nome VARCHAR2(100) NOT NULL,
    email VARCHAR2(150) UNIQUE NOT NULL,
    senha VARCHAR2(255) NOT NULL,
    telefone VARCHAR2(20),
    tipo_usuario VARCHAR2(20) NOT NULL,
    ativo NUMBER(1) DEFAULT 1,
    ultimo_login TIMESTAMP,
    data_criacao TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT chk_tipo_usuario 
        CHECK (tipo_usuario IN ('TUTOR', 'VETERINARIO')),

    CONSTRAINT chk_users_ativo 
        CHECK (ativo IN (0,1))
);

-- 2. VETERINARIOS

CREATE TABLE veterinarios (
    id NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id NUMBER NOT NULL,
    crmv VARCHAR2(50) NOT NULL,
    especialidade VARCHAR2(100),
    descricao VARCHAR2(500),

    CONSTRAINT fk_vet_user 
        FOREIGN KEY (user_id) REFERENCES users(id)
);


-- 3. PETS

CREATE TABLE pets (
    id NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id NUMBER NOT NULL,
    nome VARCHAR2(100) NOT NULL,
    especie VARCHAR2(50) NOT NULL,
    raca VARCHAR2(100),
    data_nascimento DATE,
    observacoes VARCHAR2(500),

    CONSTRAINT fk_pet_user 
        FOREIGN KEY (user_id) REFERENCES users(id)
);


-- 4. PET_VETERINARIO

CREATE TABLE pet_veterinario (
    id NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    pet_id NUMBER NOT NULL,
    veterinario_id NUMBER NOT NULL,
    data_inicio DATE DEFAULT SYSDATE,
    ativo NUMBER(1) DEFAULT 1,
    observacoes VARCHAR2(500),

    CONSTRAINT fk_pv_pet 
        FOREIGN KEY (pet_id) REFERENCES pets(id),

    CONSTRAINT fk_pv_vet 
        FOREIGN KEY (veterinario_id) REFERENCES veterinarios(id),

    CONSTRAINT chk_pv_ativo 
        CHECK (ativo IN (0,1))
);


-- 5. DIARIO_ENTRADAS

CREATE TABLE diario_entradas (
    id NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    pet_id NUMBER NOT NULL,
    data DATE NOT NULL,
    criado_em TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    atualizado_em TIMESTAMP,
    resumo VARCHAR2(1000),
    humor_geral VARCHAR2(50),
    status VARCHAR2(20),

    CONSTRAINT fk_diario_pet 
        FOREIGN KEY (pet_id) REFERENCES pets(id),

    CONSTRAINT uq_pet_data 
        UNIQUE (pet_id, data),

    CONSTRAINT chk_diario_status 
        CHECK (status IN ('COMPLETO', 'PARCIAL', 'VAZIO'))
);

-- 6. REGISTROS

CREATE TABLE registros (
    id NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    entrada_id NUMBER NOT NULL,
    tipo VARCHAR2(50) NOT NULL,
    subtipo VARCHAR2(50),
    valor NUMBER(10,2),
    unidade VARCHAR2(20),
    nota VARCHAR2(500),
    horario TIMESTAMP,
    atualizado_em TIMESTAMP,

    CONSTRAINT fk_registro_entrada 
        FOREIGN KEY (entrada_id) REFERENCES diario_entradas(id)
);


-- 7. COMENTARIOS

CREATE TABLE comentarios (
    id NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    entrada_id NUMBER NOT NULL,
    user_id NUMBER NOT NULL,
    comentario VARCHAR2(1000) NOT NULL,
    criado_em TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    editado_em TIMESTAMP,

    CONSTRAINT fk_comentario_entrada 
        FOREIGN KEY (entrada_id) REFERENCES diario_entradas(id),

    CONSTRAINT fk_comentario_user 
        FOREIGN KEY (user_id) REFERENCES users(id)
);


-- 8. INSIGHTS

CREATE TABLE insights (
    id NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    pet_id NUMBER NOT NULL,
    tipo VARCHAR2(100) NOT NULL,
    descricao VARCHAR2(1000) NOT NULL,
    origem_regra VARCHAR2(100),
    nivel_alerta VARCHAR2(10),
    data_inicio DATE,
    data_fim DATE,
    criado_em TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    gerado_por VARCHAR2(50),
    status VARCHAR2(20),
    contexto CLOB,

    CONSTRAINT fk_insight_pet 
        FOREIGN KEY (pet_id) REFERENCES pets(id),

    CONSTRAINT chk_nivel_alerta 
        CHECK (nivel_alerta IN ('BAIXO', 'MEDIO', 'ALTO')),

    CONSTRAINT chk_insight_status 
        CHECK (status IN ('ATIVO', 'RESOLVIDO', 'IGNORADO'))
);

-- 9. SOLICITACOES

CREATE TABLE solicitacoes (
    id NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    pet_id NUMBER NOT NULL,
    tutor_id NUMBER NOT NULL,
    veterinario_id NUMBER NOT NULL,
    status VARCHAR2(20) NOT NULL,
    mensagem VARCHAR2(500),
    criado_em TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    respondido_em TIMESTAMP,

    CONSTRAINT fk_sol_pet 
        FOREIGN KEY (pet_id) REFERENCES pets(id),

    CONSTRAINT fk_sol_tutor 
        FOREIGN KEY (tutor_id) REFERENCES users(id),

    CONSTRAINT fk_sol_vet 
        FOREIGN KEY (veterinario_id) REFERENCES veterinarios(id),

    CONSTRAINT chk_sol_status 
        CHECK (status IN ('PENDENTE', 'ACEITA', 'RECUSADA'))
);

-- 10. ALERTAS (novo)
CREATE TABLE alertas (
    id NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    pet_id NUMBER NOT NULL,
    veterinario_id NUMBER NOT NULL,

    tipo VARCHAR2(20) NOT NULL,
    titulo VARCHAR2(150) NOT NULL,
    descricao VARCHAR2(1000),

    data_inicio TIMESTAMP NOT NULL,
    frequencia_horas NUMBER,
    data_fim TIMESTAMP,

    ativo NUMBER(1) DEFAULT 1 NOT NULL,

    CONSTRAINT fk_alerta_pet
        FOREIGN KEY (pet_id)
        REFERENCES pets(id),

    CONSTRAINT fk_alerta_veterinario
        FOREIGN KEY (veterinario_id)
        REFERENCES veterinarios(id),

    CONSTRAINT chk_alerta_tipo
        CHECK (
            tipo IN (
                'CONSULTA',
                'REMEDIO',
                'ALIMENTACAO',
                'EXERCICIO',
                'OUTROS'
            )
        ),

    CONSTRAINT chk_alerta_frequencia
        CHECK (
            frequencia_horas IS NULL
            OR frequencia_horas > 0
        ),

    CONSTRAINT chk_alerta_ativo
        CHECK (ativo IN (0, 1)),

    CONSTRAINT chk_alerta_datas
        CHECK (
            data_fim IS NULL
            OR data_fim >= data_inicio
        )
);

-- SPRINT 1 E 2
-- Requisitos do challenger:

/*Carga de dados: para cada tabela crie uma Procedure para efetuar a carga de dados daquela tabela. A carga de dados
deve ser feita por passagem de parâmetro, não façam uso de hard-code nas Procedures. Em todos os blocos devem
existir a EXCEPTION WHEN OTHERS e mais dois tratamentos de exceção a escolha do grupo. Quando ocorrer uma
exceção, o nome da procedure, o nome do usuário, a data de ocorrência de erro, o código de erro e a mensagem de
erro devem ser salvos em uma tabela de registro de logs.*/

CREATE TABLE logs_erros (
    id NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nome_procedure VARCHAR2(100),
    usuario_bd VARCHAR2(100),
    data_erro TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    codigo_erro NUMBER,
    mensagem_erro VARCHAR2(4000)
);  

CREATE OR REPLACE PROCEDURE pr_log_erro (
    p_nome_procedure IN VARCHAR2,
    p_codigo_erro    IN NUMBER,
    p_mensagem_erro  IN VARCHAR2
)
IS
BEGIN

    INSERT INTO logs_erros (
        nome_procedure,
        usuario_bd,
        data_erro,
        codigo_erro,
        mensagem_erro
    )
    VALUES (
        p_nome_procedure,
        USER,
        CURRENT_TIMESTAMP,
        p_codigo_erro,
        p_mensagem_erro
    );

    COMMIT;

END;


-- user
CREATE OR REPLACE PROCEDURE pr_insert_users (
    p_nome           IN VARCHAR2,
    p_email          IN VARCHAR2,
    p_senha          IN VARCHAR2,
    p_telefone       IN VARCHAR2,
    p_tipo_usuario   IN VARCHAR2
)
IS
BEGIN

    INSERT INTO users (
        nome,
        email,
        senha,
        telefone,
        tipo_usuario
    )
    VALUES (
        p_nome,
        p_email,
        p_senha,
        p_telefone,
        p_tipo_usuario
    );

    COMMIT;

EXCEPTION

    WHEN DUP_VAL_ON_INDEX THEN
        pr_log_erro('pr_insert_users', SQLCODE, SQLERRM);

    WHEN VALUE_ERROR THEN
        pr_log_erro('pr_insert_users', SQLCODE, SQLERRM);

    WHEN OTHERS THEN
        pr_log_erro('pr_insert_users', SQLCODE, SQLERRM);

END;

-- veterinarios

CREATE OR REPLACE PROCEDURE pr_insert_veterinarios (
    p_user_id        IN NUMBER,
    p_crmv           IN VARCHAR2,
    p_especialidade  IN VARCHAR2,
    p_descricao      IN VARCHAR2
)
IS
BEGIN

    INSERT INTO veterinarios (
        user_id,
        crmv,
        especialidade,
        descricao
    )
    VALUES (
        p_user_id,
        p_crmv,
        p_especialidade,
        p_descricao
    );

    COMMIT;

EXCEPTION

    WHEN NO_DATA_FOUND THEN
        pr_log_erro('pr_insert_veterinarios', SQLCODE, SQLERRM);

    WHEN VALUE_ERROR THEN
        pr_log_erro('pr_insert_veterinarios', SQLCODE, SQLERRM);

    WHEN OTHERS THEN
        pr_log_erro('pr_insert_veterinarios', SQLCODE, SQLERRM);

END;

-- pets
CREATE OR REPLACE PROCEDURE pr_insert_pets (
    p_user_id          IN NUMBER,
    p_nome             IN VARCHAR2,
    p_especie          IN VARCHAR2,
    p_raca             IN VARCHAR2,
    p_data_nascimento  IN DATE,
    p_observacoes      IN VARCHAR2
)
IS
BEGIN

    INSERT INTO pets (
        user_id,
        nome,
        especie,
        raca,
        data_nascimento,
        observacoes
    )
    VALUES (
        p_user_id,
        p_nome,
        p_especie,
        p_raca,
        p_data_nascimento,
        p_observacoes
    );

    COMMIT;

EXCEPTION

    WHEN NO_DATA_FOUND THEN
        pr_log_erro('pr_insert_pets', SQLCODE, SQLERRM);

    WHEN VALUE_ERROR THEN
        pr_log_erro('pr_insert_pets', SQLCODE, SQLERRM);

    WHEN OTHERS THEN
        pr_log_erro('pr_insert_pets', SQLCODE, SQLERRM);

END;

-- pet e veterinario
CREATE OR REPLACE PROCEDURE pr_insert_pet_veterinario (
    p_pet_id           IN NUMBER,
    p_veterinario_id   IN NUMBER,
    p_data_inicio      IN DATE,
    p_ativo            IN NUMBER,
    p_observacoes      IN VARCHAR2
)
IS
BEGIN

    INSERT INTO pet_veterinario (
        pet_id,
        veterinario_id,
        data_inicio,
        ativo,
        observacoes
    )
    VALUES (
        p_pet_id,
        p_veterinario_id,
        p_data_inicio,
        p_ativo,
        p_observacoes
    );

    COMMIT;

EXCEPTION

    WHEN NO_DATA_FOUND THEN
        pr_log_erro('pr_insert_pet_veterinario', SQLCODE, SQLERRM);

    WHEN VALUE_ERROR THEN
        pr_log_erro('pr_insert_pet_veterinario', SQLCODE, SQLERRM);

    WHEN OTHERS THEN
        pr_log_erro('pr_insert_pet_veterinario', SQLCODE, SQLERRM);

END;

-- diario entradas
CREATE OR REPLACE PROCEDURE pr_insert_diario_entradas (
    p_pet_id         IN NUMBER,
    p_data           IN DATE,
    p_resumo         IN VARCHAR2,
    p_humor_geral    IN VARCHAR2,
    p_status         IN VARCHAR2
)
IS
BEGIN

    INSERT INTO diario_entradas (
        pet_id,
        data,
        resumo,
        humor_geral,
        status
    )
    VALUES (
        p_pet_id,
        p_data,
        p_resumo,
        p_humor_geral,
        p_status
    );

    COMMIT;

EXCEPTION

    WHEN DUP_VAL_ON_INDEX THEN
        pr_log_erro('pr_insert_diario_entradas', SQLCODE, SQLERRM);

    WHEN VALUE_ERROR THEN
        pr_log_erro('pr_insert_diario_entradas', SQLCODE, SQLERRM);

    WHEN OTHERS THEN
        pr_log_erro('pr_insert_diario_entradas', SQLCODE, SQLERRM);

END;

-- registros

CREATE OR REPLACE PROCEDURE pr_insert_registros (
    p_entrada_id     IN NUMBER,
    p_tipo           IN VARCHAR2,
    p_subtipo        IN VARCHAR2,
    p_valor          IN NUMBER,
    p_unidade        IN VARCHAR2,
    p_nota           IN VARCHAR2,
    p_horario        IN TIMESTAMP
)
IS
BEGIN

    INSERT INTO registros (
        entrada_id,
        tipo,
        subtipo,
        valor,
        unidade,
        nota,
        horario
    )
    VALUES (
        p_entrada_id,
        p_tipo,
        p_subtipo,
        p_valor,
        p_unidade,
        p_nota,
        p_horario
    );

    COMMIT;

EXCEPTION

    WHEN VALUE_ERROR THEN
        pr_log_erro('pr_insert_registros', SQLCODE, SQLERRM);

    WHEN INVALID_NUMBER THEN
        pr_log_erro('pr_insert_registros', SQLCODE, SQLERRM);

    WHEN OTHERS THEN
        pr_log_erro('pr_insert_registros', SQLCODE, SQLERRM);

END;

-- comentarios

CREATE OR REPLACE PROCEDURE pr_insert_comentarios (
    p_entrada_id    IN NUMBER,
    p_user_id       IN NUMBER,
    p_comentario    IN VARCHAR2
)
IS
BEGIN

    INSERT INTO comentarios (
        entrada_id,
        user_id,
        comentario
    )
    VALUES (
        p_entrada_id,
        p_user_id,
        p_comentario
    );

    COMMIT;

EXCEPTION

    WHEN VALUE_ERROR THEN
        pr_log_erro('pr_insert_comentarios', SQLCODE, SQLERRM);

    WHEN NO_DATA_FOUND THEN
        pr_log_erro('pr_insert_comentarios', SQLCODE, SQLERRM);

    WHEN OTHERS THEN
        pr_log_erro('pr_insert_comentarios', SQLCODE, SQLERRM);

END;

-- insights

CREATE OR REPLACE PROCEDURE pr_insert_insights (
    p_pet_id           IN NUMBER,
    p_tipo             IN VARCHAR2,
    p_descricao        IN VARCHAR2,
    p_origem_regra     IN VARCHAR2,
    p_nivel_alerta     IN VARCHAR2,
    p_data_inicio      IN DATE,
    p_data_fim         IN DATE,
    p_gerado_por       IN VARCHAR2,
    p_status           IN VARCHAR2,
    p_contexto         IN CLOB
)
IS
BEGIN

    INSERT INTO insights (
        pet_id,
        tipo,
        descricao,
        origem_regra,
        nivel_alerta,
        data_inicio,
        data_fim,
        gerado_por,
        status,
        contexto
    )
    VALUES (
        p_pet_id,
        p_tipo,
        p_descricao,
        p_origem_regra,
        p_nivel_alerta,
        p_data_inicio,
        p_data_fim,
        p_gerado_por,
        p_status,
        p_contexto
    );

    COMMIT;

EXCEPTION

    WHEN VALUE_ERROR THEN
        pr_log_erro('pr_insert_insights', SQLCODE, SQLERRM);

    WHEN NO_DATA_FOUND THEN
        pr_log_erro('pr_insert_insights', SQLCODE, SQLERRM);

    WHEN OTHERS THEN
        pr_log_erro('pr_insert_insights', SQLCODE, SQLERRM);

END;

-- solicitacoes

CREATE OR REPLACE PROCEDURE pr_insert_solicitacoes (
    p_pet_id           IN NUMBER,
    p_tutor_id         IN NUMBER,
    p_veterinario_id   IN NUMBER,
    p_status           IN VARCHAR2,
    p_mensagem         IN VARCHAR2,
    p_respondido_em    IN TIMESTAMP
)
IS
BEGIN

    INSERT INTO solicitacoes (
        pet_id,
        tutor_id,
        veterinario_id,
        status,
        mensagem,
        respondido_em
    )
    VALUES (
        p_pet_id,
        p_tutor_id,
        p_veterinario_id,
        p_status,
        p_mensagem,
        p_respondido_em
    );

    COMMIT;

EXCEPTION

    WHEN VALUE_ERROR THEN
        pr_log_erro('pr_insert_solicitacoes', SQLCODE, SQLERRM);

    WHEN NO_DATA_FOUND THEN
        pr_log_erro('pr_insert_solicitacoes', SQLCODE, SQLERRM);

    WHEN OTHERS THEN
        pr_log_erro('pr_insert_solicitacoes', SQLCODE, SQLERRM);

END;

-- inserindo valores

-- USERS
BEGIN

    pr_insert_users(
        'Ana Souza',
        'ana@email.com',
        '123',
        '11999990001',
        'TUTOR'
    );

    pr_insert_users(
        'Carlos Lima',
        'carlos@email.com',
        '123',
        '11999990002',
        'TUTOR'
    );

    pr_insert_users(
        'Dra. Mariana Alves',
        'mariana@email.com',
        '123',
        '11999990003',
        'VETERINARIO'
    );

    pr_insert_users(
        'Dr. Felipe Costa',
        'felipe@email.com',
        '123',
        '11999990004',
        'VETERINARIO'
    );

END;


-- VETERINARIOS
BEGIN

    pr_insert_veterinarios(
        3,
        'CRMV-SP-1001',
        'Clínica Geral',
        'Especialista em pequenos animais'
    );

    pr_insert_veterinarios(
        4,
        'CRMV-SP-1002',
        'Dermatologia',
        'Atendimento especializado em cães e gatos'
    );

END;


-- PETS
BEGIN

    pr_insert_pets(
        1,
        'Luna',
        'Cachorro',
        'Shih-tzu',
        TO_DATE('2020-05-10','YYYY-MM-DD'),
        'Pet muito dócil'
    );

    pr_insert_pets(
        1,
        'Mimi',
        'Gato',
        'Siamês',
        TO_DATE('2021-08-15','YYYY-MM-DD'),
        'Gosta de dormir o dia inteiro'
    );

    pr_insert_pets(
        2,
        'Thor',
        'Cachorro',
        'Golden Retriever',
        TO_DATE('2019-03-20','YYYY-MM-DD'),
        'Muito ativo'
    );

END;

-- PET_VETERINARIO
BEGIN

    pr_insert_pet_veterinario(
        1,
        1,
        SYSDATE,
        1,
        'Acompanhamento mensal'
    );

    pr_insert_pet_veterinario(
        2,
        2,
        SYSDATE,
        1,
        'Acompanhamento dermatológico'
    );

    pr_insert_pet_veterinario(
        3,
        1,
        SYSDATE,
        1,
        'Controle alimentar'
    );

END;


-- DIARIO_ENTRADAS
BEGIN

    pr_insert_diario_entradas(
        1,
        TO_DATE('2026-05-10','YYYY-MM-DD'),
        'Luna comeu menos que o normal',
        'Quieta',
        'COMPLETO'
    );

    pr_insert_diario_entradas(
        2,
        TO_DATE('2026-05-10','YYYY-MM-DD'),
        'Mimi dormiu bastante durante o dia',
        'Calma',
        'COMPLETO'
    );

    pr_insert_diario_entradas(
        3,
        TO_DATE('2026-05-10','YYYY-MM-DD'),
        'Thor brincou muito no parque',
        'Animado',
        'COMPLETO'
    );

END;


-- REGISTROS

BEGIN

    pr_insert_registros(
        1,
        'ALIMENTACAO',
        'RACAO',
        80,
        'g',
        'Comeu menos que o habitual',
        CURRENT_TIMESTAMP
    );

    pr_insert_registros(
        1,
        'COMPORTAMENTO',
        'QUIETO',
        NULL,
        NULL,
        'Ficou quieta durante a manhã',
        CURRENT_TIMESTAMP
    );

    pr_insert_registros(
        2,
        'ATIVIDADE',
        'SONO',
        10,
        'h',
        'Dormiu bastante',
        CURRENT_TIMESTAMP
    );

    pr_insert_registros(
        3,
        'ATIVIDADE',
        'EXERCICIO',
        2,
        'h',
        'Passeio no parque',
        CURRENT_TIMESTAMP
    );

END;


-- COMENTARIOS

BEGIN

    pr_insert_comentarios(
        1,
        3,
        'Monitorar alimentação nos próximos dias'
    );

    pr_insert_comentarios(
        2,
        4,
        'Comportamento aparentemente normal'
    );

    pr_insert_comentarios(
        3,
        3,
        'Excelente nível de atividade'
    );

END;


-- INSIGHTS
BEGIN

    pr_insert_insights(
        1,
        'ALIMENTACAO_BAIXA',
        'Redução alimentar identificada nos últimos 3 dias',
        'REGRA_MEDIA_ALIMENTACAO',
        'MEDIO',
        TO_DATE('2026-05-08','YYYY-MM-DD'),
        NULL,
        'ChatGPT',
        'ATIVO',
        '{"variacao":"-30%"}'
    );

    pr_insert_insights(
        2,
        'ATIVIDADE_REDUZIDA',
        'Baixa atividade detectada',
        'REGRA_ATIVIDADE',
        'BAIXO',
        TO_DATE('2026-05-09','YYYY-MM-DD'),
        NULL,
        'ChatGPT',
        'ATIVO',
        '{"atividade":"sono excessivo"}'
    );

    pr_insert_insights(
        3,
        'ATIVIDADE_ALTA',
        'Nível de atividade acima da média',
        'REGRA_EXERCICIO',
        'BAIXO',
        TO_DATE('2026-05-10','YYYY-MM-DD'),
        NULL,
        'ChatGPT',
        'ATIVO',
        '{"tempo_exercicio":"2h"}'
    );

END;


-- SOLICITACOES
BEGIN

    pr_insert_solicitacoes(
        1,
        1,
        1,
        'ACEITA',
        'Gostaria de acompanhamento mensal',
        CURRENT_TIMESTAMP
    );

    pr_insert_solicitacoes(
        2,
        1,
        2,
        'PENDENTE',
        'Preciso de ajuda com alergias',
        NULL
    );

    pr_insert_solicitacoes(
        3,
        2,
        1,
        'ACEITA',
        'Consulta preventiva',
        CURRENT_TIMESTAMP
    );

END;



/*Criar dois blocos anônimos para mostrar os dados inseridos, com pelo menos 3 consultas de junções (Joins) utilizando
agrupamento (group by) e ordenação (order by)*/


-- Quantidade de pets por tutor e espécie

SET SERVEROUTPUT ON;

DECLARE
BEGIN

    DBMS_OUTPUT.PUT_LINE('RELATÓRIO DE PETS POR TUTOR');
    DBMS_OUTPUT.PUT_LINE('------------------------------------------');

    FOR r IN (

        SELECT
            u.nome AS tutor,
            p.especie,
            COUNT(p.id) AS total_pets

        FROM users u

        INNER JOIN pets p
            ON u.id = p.user_id

        WHERE u.tipo_usuario = 'TUTOR'

        GROUP BY
            u.nome,
            p.especie

        ORDER BY
            total_pets DESC,
            u.nome ASC

    )

    LOOP

        DBMS_OUTPUT.PUT_LINE(
            'Tutor: ' || r.tutor ||
            ' | Espécie: ' || r.especie ||
            ' | Total Pets: ' || r.total_pets
        );

    END LOOP;

END;


-- Quantidade de insights por veterinário e nível de alerta

SET SERVEROUTPUT ON;

DECLARE
BEGIN

    DBMS_OUTPUT.PUT_LINE('RELATÓRIO DE INSIGHTS POR VETERINÁRIO');
    DBMS_OUTPUT.PUT_LINE('------------------------------------------------');

    FOR r IN (

        SELECT
            u.nome AS veterinario,
            i.nivel_alerta,
            COUNT(i.id) AS total_insights

        FROM insights i

        INNER JOIN pets p
            ON i.pet_id = p.id

        INNER JOIN pet_veterinario pv
            ON p.id = pv.pet_id

        INNER JOIN veterinarios v
            ON pv.veterinario_id = v.id

        INNER JOIN users u
            ON v.user_id = u.id

        GROUP BY
            u.nome,
            i.nivel_alerta

        ORDER BY
            u.nome ASC,
            total_insights DESC

    )

    LOOP

        DBMS_OUTPUT.PUT_LINE(
            'Veterinário: ' || r.veterinario ||
            ' | Nível Alerta: ' || r.nivel_alerta ||
            ' | Total Insights: ' || r.total_insights
        );

    END LOOP;

END;

/*Criar um bloco que deverá ler os dados de uma tabela e, na mesma linha, mostrar o valor de uma coluna da linha atual, o valor
dessa mesma coluna na linha anterior e o valor dessa mesma coluna na próxima linha. Caso a linha anterior ou a próxima linha não
existir, apresentar a palavra "Vazio". O relatório deve ter, pelo menos, cinco linhas de dados. A tabela e a coluna a ser exibida fica a
cargo do grupo*/
-- TABELA: REGISTROS
-- COLUNA ANALISADA: VALOR


SET SERVEROUTPUT ON;

DECLARE

    CURSOR c_registros IS
        SELECT
            id,
            entrada_id,
            valor,

            LAG(valor)
                OVER (ORDER BY id) AS valor_anterior,

            LEAD(valor)
                OVER (ORDER BY id) AS valor_proximo

        FROM registros

        WHERE valor IS NOT NULL

        ORDER BY id;

BEGIN

    DBMS_OUTPUT.PUT_LINE(
        RPAD('ID',10) ||
        RPAD('ENTRADA',12) ||
        RPAD('ANTERIOR',15) ||
        RPAD('ATUAL',15) ||
        RPAD('PROXIMO',15)
    );

    DBMS_OUTPUT.PUT_LINE(
        '---------------------------------------------------------------'
    );

    FOR r IN c_registros LOOP

        DBMS_OUTPUT.PUT_LINE(

            RPAD(r.id,10) ||

            RPAD(r.entrada_id,12) ||

            RPAD(
                NVL(TO_CHAR(r.valor_anterior), 'Vazio'),
                15
            ) ||

            RPAD(
                TO_CHAR(r.valor),
                15
            ) ||

            RPAD(
                NVL(TO_CHAR(r.valor_proximo), 'Vazio'),
                15
            )

        );

    END LOOP;

END;

/*Relatórios: crie quatro blocos anônimos que usem cursor explícito e tomada de decisão. Um dos blocos anônimos deve listar todos
os dados de uma tabela, mostrar os dados numéricos sumarizados e mostrar a sumarização dos dados agrupados por um critério
definido pelo grupo*/

-- RELATÓRIO 1
-- LISTAR PETS, SOMAR QUANTIDADE POR TUTOR E TOTAL GERAL

SET SERVEROUTPUT ON;

DECLARE

    CURSOR c_relatorio IS
        SELECT 
            u.nome AS tutor,
            p.nome AS pet,
            p.especie
        FROM users u
        JOIN pets p
            ON u.id = p.user_id
        WHERE u.tipo_usuario = 'TUTOR'
        ORDER BY u.nome, p.nome;

    v_tutor_anterior users.nome%TYPE := '';
    v_qtd_tutor NUMBER := 0;
    v_total_geral NUMBER := 0;

BEGIN

    DBMS_OUTPUT.PUT_LINE('TUTOR | PET | ESPECIE');
    DBMS_OUTPUT.PUT_LINE('-----------------------------------------');

    FOR r IN c_relatorio LOOP

        IF v_tutor_anterior IS NULL OR v_tutor_anterior = '' THEN
            v_tutor_anterior := r.tutor;
        END IF;

        IF v_tutor_anterior <> r.tutor THEN

            DBMS_OUTPUT.PUT_LINE(
                'SUBTOTAL DE PETS DE ' || v_tutor_anterior ||
                ': ' || v_qtd_tutor
            );

            DBMS_OUTPUT.PUT_LINE('-----------------------------------------');

            v_qtd_tutor := 0;
            v_tutor_anterior := r.tutor;

        END IF;

        DBMS_OUTPUT.PUT_LINE(
            r.tutor || ' | ' ||
            r.pet || ' | ' ||
            r.especie
        );

        v_qtd_tutor := v_qtd_tutor + 1;
        v_total_geral := v_total_geral + 1;

    END LOOP;

    DBMS_OUTPUT.PUT_LINE(
        'SUBTOTAL DE PETS DE ' || v_tutor_anterior ||
        ': ' || v_qtd_tutor
    );

    DBMS_OUTPUT.PUT_LINE('=========================================');

    DBMS_OUTPUT.PUT_LINE(
        'TOTAL GERAL DE PETS: ' || v_total_geral
    );

END;


-- RELATÓRIO 2
-- MOSTRAR INSIGHTS E CLASSIFICAR NÍVEL DE ALERTA

SET SERVEROUTPUT ON;

DECLARE

    CURSOR c_insights IS
        SELECT
            p.nome AS pet,
            i.tipo,
            i.nivel_alerta,
            i.status
        FROM insights i
        JOIN pets p
            ON i.pet_id = p.id
        ORDER BY i.nivel_alerta DESC;

BEGIN

    DBMS_OUTPUT.PUT_LINE('PET | TIPO | ALERTA | CLASSIFICACAO');
    DBMS_OUTPUT.PUT_LINE('------------------------------------------------');

    FOR r IN c_insights LOOP

        IF r.nivel_alerta = 'ALTO' THEN

            DBMS_OUTPUT.PUT_LINE(
                r.pet || ' | ' ||
                r.tipo || ' | ' ||
                r.nivel_alerta || ' | URGENTE'
            );

        ELSIF r.nivel_alerta = 'MEDIO' THEN

            DBMS_OUTPUT.PUT_LINE(
                r.pet || ' | ' ||
                r.tipo || ' | ' ||
                r.nivel_alerta || ' | ATENCAO'
            );

        ELSE

            DBMS_OUTPUT.PUT_LINE(
                r.pet || ' | ' ||
                r.tipo || ' | ' ||
                r.nivel_alerta || ' | NORMAL'
            );

        END IF;

    END LOOP;

END;

-- RELATÓRIO 3
-- LISTAR SOLICITAÇÕES E EXIBIR SITUAÇÃO

SET SERVEROUTPUT ON;

DECLARE

    CURSOR c_solicitacoes IS
        SELECT
            s.id,
            p.nome AS pet,
            u.nome AS tutor,
            s.status
        FROM solicitacoes s
        JOIN pets p
            ON s.pet_id = p.id
        JOIN users u
            ON s.tutor_id = u.id
        ORDER BY s.id;

    v_situacao VARCHAR2(50);

BEGIN

    DBMS_OUTPUT.PUT_LINE('ID | PET | TUTOR | STATUS');
    DBMS_OUTPUT.PUT_LINE('------------------------------------------------');

    FOR r IN c_solicitacoes LOOP

        CASE r.status

            WHEN 'PENDENTE' THEN
                v_situacao := 'AGUARDANDO';

            WHEN 'ACEITA' THEN
                v_situacao := 'APROVADA';

            WHEN 'RECUSADA' THEN
                v_situacao := 'NEGADA';

            ELSE
                v_situacao := 'DESCONHECIDO';

        END CASE;

        DBMS_OUTPUT.PUT_LINE(
            r.id || ' | ' ||
            r.pet || ' | ' ||
            r.tutor || ' | ' ||
            v_situacao
        );

    END LOOP;

END;


-- RELATÓRIO 4
-- MOSTRAR REGISTROS E IDENTIFICAR VALORES ALTOS

SET SERVEROUTPUT ON;

DECLARE

    CURSOR c_registros IS
        SELECT
            p.nome AS pet,
            r.tipo,
            r.valor,
            r.unidade
        FROM registros r
        JOIN diario_entradas d
            ON r.entrada_id = d.id
        JOIN pets p
            ON d.pet_id = p.id
        ORDER BY r.valor DESC;

BEGIN

    DBMS_OUTPUT.PUT_LINE('PET | TIPO | VALOR | ANALISE');
    DBMS_OUTPUT.PUT_LINE('------------------------------------------------');

    FOR r IN c_registros LOOP

        IF r.valor >= 500 THEN

            DBMS_OUTPUT.PUT_LINE(
                r.pet || ' | ' ||
                r.tipo || ' | ' ||
                r.valor || ' ' || r.unidade ||
                ' | VALOR ALTO'
            );

        ELSIF r.valor >= 100 THEN

            DBMS_OUTPUT.PUT_LINE(
                r.pet || ' | ' ||
                r.tipo || ' | ' ||
                r.valor || ' ' || r.unidade ||
                ' | VALOR MEDIO'
            );

        ELSE

            DBMS_OUTPUT.PUT_LINE(
                r.pet || ' | ' ||
                r.tipo || ' | ' ||
                r.valor || ' ' || r.unidade ||
                ' | VALOR BAIXO'
            );

        END IF;

    END LOOP;

END;



/* 
   SPRINT 3 

   Entregas:
   1. Função 1 - transformação relacional para JSON manual
   2. Função 2 - cálculo lógico relacionado ao projeto
   3. Procedure 1 - JOIN + saída JSON
   4. Procedure 2 - agrupamento manual com subtotais e total geral
   5. Trigger de auditoria DML
   6. Blocos de teste / evidências de execução
*/


/* 
   FUNÇÃO 1
   Recebe o ID de um pet, consulta dados relacionais e devolve
   uma string JSON montada manualmente.

   IMPORTANTE:
   Não são utilizadas TO_JSON, JSON_OBJECT, JSON_VALUE,
   JSON_QUERY, JSON_TABLE ou funções equivalentes de JSON.
 */

CREATE OR REPLACE FUNCTION fn_pet_json (
    p_pet_id IN NUMBER
)
RETURN VARCHAR2
IS
    v_pet_id           pets.id%TYPE;
    v_nome_pet         pets.nome%TYPE;
    v_especie          pets.especie%TYPE;
    v_raca             pets.raca%TYPE;
    v_data_nascimento  pets.data_nascimento%TYPE;
    v_nome_tutor       users.nome%TYPE;
    v_nome_veterinario users.nome%TYPE;
BEGIN

    SELECT
        p.id,
        p.nome,
        p.especie,
        p.raca,
        p.data_nascimento,
        u.nome,
        (
            SELECT u2.nome
            FROM veterinarios v2
            JOIN users u2
                ON u2.id = v2.user_id
            JOIN pet_veterinario pv2
                ON pv2.veterinario_id = v2.id
            WHERE pv2.pet_id = p.id
              AND pv2.ativo = 1
              AND ROWNUM = 1
        )
    INTO
        v_pet_id,
        v_nome_pet,
        v_especie,
        v_raca,
        v_data_nascimento,
        v_nome_tutor,
        v_nome_veterinario
    FROM pets p
    JOIN users u
        ON u.id = p.user_id
    WHERE p.id = p_pet_id;

    RETURN
        '{' ||
        '"pet_id":' ||
            TO_CHAR(v_pet_id) ||
        ',"nome":"' ||
            REPLACE(REPLACE(NVL(v_nome_pet, ''), '\', '\\'), '"', '\"') ||
        '"' ||
        ',"especie":"' ||
            REPLACE(REPLACE(NVL(v_especie, ''), '\', '\\'), '"', '\"') ||
        '"' ||
        ',"raca":"' ||
            REPLACE(REPLACE(NVL(v_raca, ''), '\', '\\'), '"', '\"') ||
        '"' ||
        ',"data_nascimento":"' ||
            NVL(TO_CHAR(v_data_nascimento, 'YYYY-MM-DD'), '') ||
        '"' ||
        ',"tutor":"' ||
            REPLACE(REPLACE(NVL(v_nome_tutor, ''), '\', '\\'), '"', '\"') ||
        '"' ||
        ',"veterinario":"' ||
            REPLACE(REPLACE(NVL(v_nome_veterinario, ''), '\', '\\'), '"', '\"') ||
        '"' ||
        '}';

EXCEPTION

    WHEN NO_DATA_FOUND THEN
        RETURN '{"erro":"Pet não encontrado","codigo":-1403}';

    WHEN VALUE_ERROR THEN
        RETURN '{"erro":"Erro de conversão ou valor inválido","codigo":-6502}';

    WHEN OTHERS THEN
        RETURN
            '{"erro":"Erro inesperado na função fn_pet_json","codigo":' ||
            TO_CHAR(SQLCODE) ||
            ',"mensagem":"' ||
            REPLACE(REPLACE(SQLERRM, '\', '\\'), '"', '\"') ||
            '"}';

END;

-- Teste função 1

SET SERVEROUTPUT ON;

BEGIN

    DBMS_OUTPUT.PUT_LINE('TESTE FUNÇÃO 1');
    DBMS_OUTPUT.PUT_LINE(fn_pet_json(1));

    DBMS_OUTPUT.PUT_LINE('TESTE DE EXCEÇÃO - PET INEXISTENTE');
    DBMS_OUTPUT.PUT_LINE(fn_pet_json(99999));

END;

/* 
   FUNÇÃO 2
   Processo lógico do projeto:
   calcula a idade do pet a partir da sua data de nascimento.

   A função recebe o ID do pet, busca sua data de nascimento e
   realiza o cálculo sem depender de uma coluna de idade armazenada.
*/

CREATE OR REPLACE FUNCTION fn_calcular_idade_pet (
    p_pet_id IN NUMBER
)
RETURN NUMBER
IS
    v_data_nascimento pets.data_nascimento%TYPE;
    v_idade NUMBER;

    e_pet_inexistente EXCEPTION;
    e_data_futura EXCEPTION;
BEGIN

    BEGIN
        SELECT data_nascimento
        INTO v_data_nascimento
        FROM pets
        WHERE id = p_pet_id;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE e_pet_inexistente;
    END;

    IF v_data_nascimento IS NULL THEN
        RAISE VALUE_ERROR;
    END IF;

    IF v_data_nascimento > SYSDATE THEN
        RAISE e_data_futura;
    END IF;

    v_idade := TRUNC(MONTHS_BETWEEN(SYSDATE, v_data_nascimento) / 12);

    RETURN v_idade;

EXCEPTION

    WHEN e_pet_inexistente THEN
        DBMS_OUTPUT.PUT_LINE(
            'ERRO fn_calcular_idade_pet: pet não encontrado.'
        );
        RETURN NULL;

    WHEN e_data_futura THEN
        DBMS_OUTPUT.PUT_LINE(
            'ERRO fn_calcular_idade_pet: data de nascimento futura.'
        );
        RETURN NULL;

    WHEN VALUE_ERROR THEN
        DBMS_OUTPUT.PUT_LINE(
            'ERRO fn_calcular_idade_pet: data de nascimento inválida ou nula.'
        );
        RETURN NULL;

    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE(
            'ERRO fn_calcular_idade_pet: ' ||
            SQLCODE || ' - ' || SQLERRM
        );
        RETURN NULL;

END;

-- Teste função 2

SET SERVEROUTPUT ON;

BEGIN

    DBMS_OUTPUT.PUT_LINE('TESTE FUNÇÃO 2');
    DBMS_OUTPUT.PUT_LINE(
        'Idade da Luna: ' || fn_calcular_idade_pet(1) || ' anos'
    );

    DBMS_OUTPUT.PUT_LINE('TESTE DE EXCEÇÃO');
    DBMS_OUTPUT.PUT_LINE(
        'Idade do pet inexistente: ' ||
        NVL(TO_CHAR(fn_calcular_idade_pet(99999)), 'NULL')
    );

END;



/* 
   PROCEDURE 1
   Realiza JOIN entre várias tabelas e exibe os dados no formato
   JSON utilizando a Função 1 criada pelo grupo.

   A procedure faz o JOIN entre:
   PETS
   USERS
   PET_VETERINARIO
   VETERINARIOS

   A transformação para JSON é feita pela FN_PET_JSON.
 */

CREATE OR REPLACE PROCEDURE pr_relatorio_pets_json
IS
    v_quantidade NUMBER := 0;
BEGIN

    DBMS_OUTPUT.PUT_LINE('PROCEDURE 1 - PETS EM JSON');

    FOR r IN (
        SELECT
            p.id AS pet_id,
            p.nome AS pet,
            u.nome AS tutor,
            v.id AS veterinario_id,
            vu.nome AS veterinario
        FROM pets p
        JOIN users u
            ON u.id = p.user_id
        LEFT JOIN pet_veterinario pv
            ON pv.pet_id = p.id
           AND pv.ativo = 1
        LEFT JOIN veterinarios v
            ON v.id = pv.veterinario_id
        LEFT JOIN users vu
            ON vu.id = v.user_id
        ORDER BY p.id
    )
    LOOP

        v_quantidade := v_quantidade + 1;

        DBMS_OUTPUT.PUT_LINE(
            'JOIN -> Pet: ' || r.pet ||
            ' | Tutor: ' || r.tutor ||
            ' | Veterinário: ' || NVL(r.veterinario, 'NULL')
        );

        DBMS_OUTPUT.PUT_LINE(
            'JSON -> ' || fn_pet_json(r.pet_id)
        );

    END LOOP;

    IF v_quantidade = 0 THEN
        RAISE NO_DATA_FOUND;
    END IF;

EXCEPTION

    WHEN NO_DATA_FOUND THEN
        DBMS_OUTPUT.PUT_LINE(
            'ERRO pr_relatorio_pets_json: nenhum registro encontrado.'
        );
        pr_log_erro(
            'pr_relatorio_pets_json',
            SQLCODE,
            SQLERRM
        );

    WHEN VALUE_ERROR THEN
        DBMS_OUTPUT.PUT_LINE(
            'ERRO pr_relatorio_pets_json: valor inválido.'
        );
        pr_log_erro(
            'pr_relatorio_pets_json',
            SQLCODE,
            SQLERRM
        );

    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE(
            'ERRO pr_relatorio_pets_json: ' ||
            SQLCODE || ' - ' || SQLERRM
        );
        pr_log_erro(
            'pr_relatorio_pets_json',
            SQLCODE,
            SQLERRM
        );

END;



-- Teste procedure 1

SET SERVEROUTPUT ON;

BEGIN

    pr_relatorio_pets_json;

END;



/* 
   CARGA COMPLEMENTAR PARA A PROCEDURE 2

   A tabela REGISTROS possuía 4 registros na versão anterior.
   São adicionados 2 registros numéricos para garantir pelo menos
   5 linhas com valores numéricos e também demonstrar a soma
   manual de uma mesma combinação de categorias.
 */

BEGIN

    pr_insert_registros(
        1,
        'ALIMENTACAO',
        'RACAO',
        20,
        'g',
        'Complemento da alimentação',
        CURRENT_TIMESTAMP
    );

    pr_insert_registros(
        2,
        'ALIMENTACAO',
        'AGUA',
        500,
        'ml',
        'Consumo de água',
        CURRENT_TIMESTAMP
    );

END;



/*
   PROCEDURE 2
   Usa a tabela REGISTROS como tabela de fatos.

   Categorias:
   1. TIPO
   2. SUBTIPO

   Valor numérico:
   3. VALOR

   O agrupamento e as somas são realizados MANUALMENTE,
   sem SUM, ROLLUP, CUBE, GROUPING SETS ou GROUPING.

   A saída possui:
   - linhas detalhadas por combinação TIPO + SUBTIPO;
   - subtotal por TIPO;
   - total geral.

   Os subtotais e o total geral são impressos com NULL nas
   categorias que deixam de participar daquele nível.
*/

CREATE OR REPLACE PROCEDURE pr_relatorio_registros_agrupado
IS
    CURSOR c_registros IS
        SELECT
            tipo,
            subtipo,
            valor
        FROM registros
        WHERE valor IS NOT NULL
        ORDER BY tipo, subtipo, id;

    v_tipo_atual          registros.tipo%TYPE := NULL;
    v_subtipo_atual       registros.subtipo%TYPE := NULL;

    v_soma_subtipo        NUMBER := 0;
    v_subtotal_tipo       NUMBER := 0;
    v_total_geral         NUMBER := 0;

    v_linhas NUMBER := 0;
BEGIN

    DBMS_OUTPUT.PUT_LINE('PROCEDURE 2 - REGISTROS AGRUPADOS');

    DBMS_OUTPUT.PUT_LINE(
        RPAD('TIPO', 20) ||
        RPAD('SUBTIPO', 20) ||
        'VALOR'
    );
    DBMS_OUTPUT.PUT_LINE('------------------------------------------------------');

    FOR r IN c_registros LOOP

        v_linhas := v_linhas + 1;

        -- Primeiro registro.
        IF v_tipo_atual IS NULL THEN

            v_tipo_atual := r.tipo;
            v_subtipo_atual := r.subtipo;
            v_soma_subtipo := 0;
            v_subtotal_tipo := 0;

        -- Mudou o TIPO.
        ELSIF v_tipo_atual <> r.tipo THEN

            -- Fecha a última combinação do tipo anterior.
            DBMS_OUTPUT.PUT_LINE(
                RPAD(v_tipo_atual, 20) ||
                RPAD(NVL(v_subtipo_atual, 'NULL'), 20) ||
                TO_CHAR(v_soma_subtipo, '9999990.00')
            );

            -- Imprime subtotal do primeiro agrupamento.
            DBMS_OUTPUT.PUT_LINE(
                RPAD(v_tipo_atual, 20) ||
                RPAD('NULL', 20) ||
                TO_CHAR(v_subtotal_tipo, '9999990.00')
            );

            DBMS_OUTPUT.PUT_LINE('------------------------------------------------------');

            -- Começa novo TIPO.
            v_tipo_atual := r.tipo;
            v_subtipo_atual := r.subtipo;
            v_soma_subtipo := 0;
            v_subtotal_tipo := 0;

        -- Mesmo TIPO, mas mudou o SUBTIPO.
        ELSIF NVL(v_subtipo_atual, '#NULL#')
              <> NVL(r.subtipo, '#NULL#') THEN

            -- Fecha a combinação anterior.
            DBMS_OUTPUT.PUT_LINE(
                RPAD(v_tipo_atual, 20) ||
                RPAD(NVL(v_subtipo_atual, 'NULL'), 20) ||
                TO_CHAR(v_soma_subtipo, '9999990.00')
            );

            -- Começa nova combinação.
            v_subtipo_atual := r.subtipo;
            v_soma_subtipo := 0;

        END IF;

        -- Soma manual da combinação atual.
        v_soma_subtipo := v_soma_subtipo + NVL(r.valor, 0);

        -- Soma manual do subtotal do TIPO.
        v_subtotal_tipo := v_subtotal_tipo + NVL(r.valor, 0);

        -- Soma manual do total geral.
        v_total_geral := v_total_geral + NVL(r.valor, 0);

    END LOOP;

    IF v_linhas = 0 THEN
        RAISE NO_DATA_FOUND;
    END IF;

    -- Fecha a última combinação.
    DBMS_OUTPUT.PUT_LINE(
        RPAD(v_tipo_atual, 20) ||
        RPAD(NVL(v_subtipo_atual, 'NULL'), 20) ||
        TO_CHAR(v_soma_subtipo, '9999990.00')
    );

    -- Subtotal do último TIPO.
    DBMS_OUTPUT.PUT_LINE(
        RPAD(v_tipo_atual, 20) ||
        RPAD('NULL', 20) ||
        TO_CHAR(v_subtotal_tipo, '9999990.00')
    );

    DBMS_OUTPUT.PUT_LINE('------------------------------------------------------');

    -- Total geral: as duas categorias ficam NULL.
    DBMS_OUTPUT.PUT_LINE(
        RPAD('NULL', 20) ||
        RPAD('NULL', 20) ||
        TO_CHAR(v_total_geral, '9999990.00')
    );

EXCEPTION

    WHEN NO_DATA_FOUND THEN
        DBMS_OUTPUT.PUT_LINE(
            'ERRO pr_relatorio_registros_agrupado: nenhum registro numérico encontrado.'
        );
        pr_log_erro(
            'pr_relatorio_registros_agrupado',
            SQLCODE,
            SQLERRM
        );

    WHEN VALUE_ERROR THEN
        DBMS_OUTPUT.PUT_LINE(
            'ERRO pr_relatorio_registros_agrupado: valor inválido.'
        );
        pr_log_erro(
            'pr_relatorio_registros_agrupado',
            SQLCODE,
            SQLERRM
        );

    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE(
            'ERRO pr_relatorio_registros_agrupado: ' ||
            SQLCODE || ' - ' || SQLERRM
        );
        pr_log_erro(
            'pr_relatorio_registros_agrupado',
            SQLCODE,
            SQLERRM
        );

END;

-- Teste procedure 2

SET SERVEROUTPUT ON;

BEGIN

    pr_relatorio_registros_agrupado;

END;



/* 
   TABELA DE AUDITORIA
   Guarda usuário, operação, data/hora, valores anteriores e
   valores novos da tabela REGISTROS.
    */

CREATE TABLE auditoria_registros (
    id_auditoria NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    usuario_bd VARCHAR2(100) NOT NULL,
    tipo_operacao VARCHAR2(10) NOT NULL,
    data_operacao TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    old_id NUMBER,
    old_entrada_id NUMBER,
    old_tipo VARCHAR2(50),
    old_subtipo VARCHAR2(50),
    old_valor NUMBER(10,2),
    old_unidade VARCHAR2(20),
    old_nota VARCHAR2(500),
    old_horario TIMESTAMP,

    new_id NUMBER,
    new_entrada_id NUMBER,
    new_tipo VARCHAR2(50),
    new_subtipo VARCHAR2(50),
    new_valor NUMBER(10,2),
    new_unidade VARCHAR2(20),
    new_nota VARCHAR2(500),
    new_horario TIMESTAMP
);


/* 
   TRIGGER DE AUDITORIA DML

   AFTER INSERT OR UPDATE OR DELETE ON REGISTROS
 */

CREATE OR REPLACE TRIGGER trg_auditoria_registros
AFTER INSERT OR UPDATE OR DELETE ON registros
FOR EACH ROW
BEGIN

    IF INSERTING THEN

        INSERT INTO auditoria_registros (
            usuario_bd,
            tipo_operacao,
            data_operacao,
            new_id,
            new_entrada_id,
            new_tipo,
            new_subtipo,
            new_valor,
            new_unidade,
            new_nota,
            new_horario
        )
        VALUES (
            USER,
            'INSERT',
            CURRENT_TIMESTAMP,
            :NEW.id,
            :NEW.entrada_id,
            :NEW.tipo,
            :NEW.subtipo,
            :NEW.valor,
            :NEW.unidade,
            :NEW.nota,
            :NEW.horario
        );

    ELSIF UPDATING THEN

        INSERT INTO auditoria_registros (
            usuario_bd,
            tipo_operacao,
            data_operacao,
            old_id,
            old_entrada_id,
            old_tipo,
            old_subtipo,
            old_valor,
            old_unidade,
            old_nota,
            old_horario,
            new_id,
            new_entrada_id,
            new_tipo,
            new_subtipo,
            new_valor,
            new_unidade,
            new_nota,
            new_horario
        )
        VALUES (
            USER,
            'UPDATE',
            CURRENT_TIMESTAMP,
            :OLD.id,
            :OLD.entrada_id,
            :OLD.tipo,
            :OLD.subtipo,
            :OLD.valor,
            :OLD.unidade,
            :OLD.nota,
            :OLD.horario,
            :NEW.id,
            :NEW.entrada_id,
            :NEW.tipo,
            :NEW.subtipo,
            :NEW.valor,
            :NEW.unidade,
            :NEW.nota,
            :NEW.horario
        );

    ELSIF DELETING THEN

        INSERT INTO auditoria_registros (
            usuario_bd,
            tipo_operacao,
            data_operacao,
            old_id,
            old_entrada_id,
            old_tipo,
            old_subtipo,
            old_valor,
            old_unidade,
            old_nota,
            old_horario
        )
        VALUES (
            USER,
            'DELETE',
            CURRENT_TIMESTAMP,
            :OLD.id,
            :OLD.entrada_id,
            :OLD.tipo,
            :OLD.subtipo,
            :OLD.valor,
            :OLD.unidade,
            :OLD.nota,
            :OLD.horario
        );

    END IF;

END;



/* 
   TESTE DA TRIGGER
   Executa INSERT, UPDATE e DELETE para gerar três registros
   de auditoria.
 */

SET SERVEROUTPUT ON;

DECLARE
    v_id_registro registros.id%TYPE;
BEGIN

    -- INSERT
    INSERT INTO registros (
        entrada_id,
        tipo,
        subtipo,
        valor,
        unidade,
        nota,
        horario
    )
    VALUES (
        1,
        'TESTE_AUDITORIA',
        'TESTE',
        10,
        'un',
        'Registro criado para testar INSERT da trigger',
        CURRENT_TIMESTAMP
    )
    RETURNING id INTO v_id_registro;

    -- UPDATE
    UPDATE registros
    SET valor = 20,
        nota = 'Registro atualizado para testar UPDATE da trigger'
    WHERE id = v_id_registro;

    -- DELETE
    DELETE FROM registros
    WHERE id = v_id_registro;

    COMMIT;

    DBMS_OUTPUT.PUT_LINE(
        'Trigger testada com sucesso: INSERT, UPDATE e DELETE.'
    );

END;




   -- EXIBIÇÃO DOS REGISTROS DE AUDITORIA PARA PRINT


BEGIN


    DBMS_OUTPUT.PUT_LINE('AUDITORIA DOS TESTES DA TRIGGER');


    FOR r IN (
        SELECT
            id_auditoria,
            usuario_bd,
            tipo_operacao,
            data_operacao,
            old_id,
            old_valor,
            new_id,
            new_valor
        FROM auditoria_registros
        ORDER BY id_auditoria
    )
    LOOP

        DBMS_OUTPUT.PUT_LINE(
            'ID: ' || r.id_auditoria ||
            ' | USUARIO: ' || r.usuario_bd ||
            ' | OPERACAO: ' || r.tipo_operacao ||
            ' | DATA: ' || TO_CHAR(r.data_operacao, 'YYYY-MM-DD HH24:MI:SS') ||
            ' | OLD_ID: ' || NVL(TO_CHAR(r.old_id), 'NULL') ||
            ' | OLD_VALOR: ' || NVL(TO_CHAR(r.old_valor), 'NULL') ||
            ' | NEW_ID: ' || NVL(TO_CHAR(r.new_id), 'NULL') ||
            ' | NEW_VALOR: ' || NVL(TO_CHAR(r.new_valor), 'NULL')
        );

    END LOOP;

END;


/*
   CONSULTAS FINAIS 

   1. Dados dos pets usados na Função 1 / Procedure 1
   2. Dados numéricos usados na Procedure 2
   3. Registros de auditoria da Trigger
*/

SELECT
    p.id,
    p.nome,
    p.especie,
    p.raca,
    u.nome AS tutor
FROM pets p
JOIN users u
    ON u.id = p.user_id
ORDER BY p.id;


SELECT
    id,
    entrada_id,
    tipo,
    subtipo,
    valor,
    unidade
FROM registros
WHERE valor IS NOT NULL
ORDER BY tipo, subtipo, id;


SELECT
    id_auditoria,
    usuario_bd,
    tipo_operacao,
    data_operacao,
    old_tipo,
    old_subtipo,
    old_valor,
    new_tipo,
    new_subtipo,
    new_valor
FROM auditoria_registros
ORDER BY id_auditoria;



