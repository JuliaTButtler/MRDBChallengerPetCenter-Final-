-- PET CENTER - SCRIPT COMPLETO (Sprints 1 a 4)
-- Executar inteiro com F5 (Run Script) em schema vazio ou já usado.
-- Este bloco inicial apaga objetos anteriores para o professor
-- testar do zero, sem ALTER TABLE.

-- 0. LIMPEZA DO SCHEMA
BEGIN

    BEGIN
        EXECUTE IMMEDIATE 'DROP TRIGGER trg_auditoria_registros';
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLCODE != -4080 THEN
                RAISE;
            END IF;
    END;

    FOR r IN (
        SELECT object_name
        FROM user_objects
        WHERE object_type = 'PACKAGE'
          AND object_name IN (
              'PKG_PETCENTER_CARGA',
              'PKG_PETCENTER_RELATORIOS',
              'PKG_PETCENTER_AUDITORIA'
          )
    ) LOOP
        EXECUTE IMMEDIATE 'DROP PACKAGE ' || r.object_name;
    END LOOP;

    FOR r IN (
        SELECT object_type, object_name
        FROM user_objects
        WHERE object_type IN ('PROCEDURE', 'FUNCTION')
          AND object_name IN (
              'PR_LOG_ERRO',
              'PR_INSERT_USERS',
              'PR_INSERT_VETERINARIOS',
              'PR_INSERT_PETS',
              'PR_INSERT_PET_VETERINARIO',
              'PR_INSERT_DIARIO_ENTRADAS',
              'PR_INSERT_REGISTROS',
              'PR_INSERT_COMENTARIOS',
              'PR_INSERT_INSIGHTS',
              'PR_INSERT_SOLICITACOES',
              'PR_INSERT_ALERTAS',
              'PR_RELATORIO_PETS_JSON',
              'PR_RELATORIO_REGISTROS_AGRUPADO',
              'FN_PET_JSON',
              'FN_CALCULAR_IDADE_PET'
          )
    ) LOOP
        EXECUTE IMMEDIATE 'DROP ' || r.object_type || ' ' || r.object_name;
    END LOOP;

    FOR r IN (
        SELECT table_name FROM (
            SELECT 'ALERTAS'              AS table_name, 1  AS ord FROM dual UNION ALL
            SELECT 'SOLICITACOES',                       2  FROM dual UNION ALL
            SELECT 'INSIGHTS',                           3  FROM dual UNION ALL
            SELECT 'COMENTARIOS',                        4  FROM dual UNION ALL
            SELECT 'AUDITORIA_REGISTROS',                5  FROM dual UNION ALL
            SELECT 'REGISTROS',                          6  FROM dual UNION ALL
            SELECT 'DIARIO_ENTRADAS',                    7  FROM dual UNION ALL
            SELECT 'PET_VETERINARIO',                    8  FROM dual UNION ALL
            SELECT 'PETS',                               9  FROM dual UNION ALL
            SELECT 'VETERINARIOS',                       10 FROM dual UNION ALL
            SELECT 'USERS',                              11 FROM dual UNION ALL
            SELECT 'LOGS_ERROS',                         12 FROM dual
        )
        ORDER BY ord
    ) LOOP
        BEGIN
            EXECUTE IMMEDIATE 'DROP TABLE ' || r.table_name || ' CASCADE CONSTRAINTS';
        EXCEPTION
            WHEN OTHERS THEN
                IF SQLCODE != -942 THEN
                    RAISE;
                END IF;
        END;
    END LOOP;

END;
/

-- ============================================================
-- 1. TABELAS
-- ============================================================

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

-- (feedback Sprint 3) tabela: auditoria_registros
-- Já nasce com old_atualizado_em e new_atualizado_em (sem ALTER TABLE).
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
    old_atualizado_em TIMESTAMP,

    new_id NUMBER,
    new_entrada_id NUMBER,
    new_tipo VARCHAR2(50),
    new_subtipo VARCHAR2(50),
    new_valor NUMBER(10,2),
    new_unidade VARCHAR2(20),
    new_nota VARCHAR2(500),
    new_horario TIMESTAMP,
    new_atualizado_em TIMESTAMP
);

-- ============================================================
-- 2. PACKAGES (Sprint 4)
-- pkg_petcenter_carga: aqui (precisa existir antes da carga).
-- pkg_petcenter_relatorios: seção 5
-- pkg_petcenter_auditoria: seção 6
-- SPRINT 4 - EMPACOTAMENTO
-- Objetos avulsos (procedures/funções) passam a viver em packages.
-- Trigger permanece fora do package (limitação do Oracle) e
-- chama a lógica empacotada.
-- ============================================================

-- (Sprint 4) package spec: pkg_petcenter_carga
-- Agrupa log de erros e todas as procedures de carga (INSERT).
CREATE OR REPLACE PACKAGE pkg_petcenter_carga AS

    PROCEDURE pr_log_erro (
        p_nome_procedure IN VARCHAR2,
        p_codigo_erro    IN NUMBER,
        p_mensagem_erro  IN VARCHAR2
    );

    PROCEDURE pr_insert_users (
        p_nome           IN VARCHAR2,
        p_email          IN VARCHAR2,
        p_senha          IN VARCHAR2,
        p_telefone       IN VARCHAR2,
        p_tipo_usuario   IN VARCHAR2
    );

    PROCEDURE pr_insert_veterinarios (
        p_user_id        IN NUMBER,
        p_crmv           IN VARCHAR2,
        p_especialidade  IN VARCHAR2,
        p_descricao      IN VARCHAR2
    );

    PROCEDURE pr_insert_pets (
        p_user_id          IN NUMBER,
        p_nome             IN VARCHAR2,
        p_especie          IN VARCHAR2,
        p_raca             IN VARCHAR2,
        p_data_nascimento  IN DATE,
        p_observacoes      IN VARCHAR2
    );

    PROCEDURE pr_insert_pet_veterinario (
        p_pet_id           IN NUMBER,
        p_veterinario_id   IN NUMBER,
        p_data_inicio      IN DATE,
        p_ativo            IN NUMBER,
        p_observacoes      IN VARCHAR2
    );

    PROCEDURE pr_insert_diario_entradas (
        p_pet_id         IN NUMBER,
        p_data           IN DATE,
        p_resumo         IN VARCHAR2,
        p_humor_geral    IN VARCHAR2,
        p_status         IN VARCHAR2
    );

    PROCEDURE pr_insert_registros (
        p_entrada_id     IN NUMBER,
        p_tipo           IN VARCHAR2,
        p_subtipo        IN VARCHAR2,
        p_valor          IN NUMBER,
        p_unidade        IN VARCHAR2,
        p_nota           IN VARCHAR2,
        p_horario        IN TIMESTAMP
    );

    PROCEDURE pr_insert_comentarios (
        p_entrada_id    IN NUMBER,
        p_user_id       IN NUMBER,
        p_comentario    IN VARCHAR2
    );

    PROCEDURE pr_insert_insights (
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
    );

    PROCEDURE pr_insert_solicitacoes (
        p_pet_id           IN NUMBER,
        p_tutor_id         IN NUMBER,
        p_veterinario_id   IN NUMBER,
        p_status           IN VARCHAR2,
        p_mensagem         IN VARCHAR2,
        p_respondido_em    IN TIMESTAMP
    );

    PROCEDURE pr_insert_alertas (
        p_pet_id            IN NUMBER,
        p_veterinario_id    IN NUMBER,
        p_tipo              IN VARCHAR2,
        p_titulo            IN VARCHAR2,
        p_descricao         IN VARCHAR2,
        p_data_inicio       IN TIMESTAMP,
        p_frequencia_horas  IN NUMBER,
        p_data_fim          IN TIMESTAMP,
        p_ativo             IN NUMBER
    );

END pkg_petcenter_carga;
/


-- (Sprint 4) package body: pkg_petcenter_carga
CREATE OR REPLACE PACKAGE BODY pkg_petcenter_carga AS

    PROCEDURE pr_log_erro (
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

    END pr_log_erro;


    -- user
    PROCEDURE pr_insert_users (
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
        pr_log_erro('pkg_petcenter_carga.pr_insert_users', SQLCODE, SQLERRM);

    WHEN VALUE_ERROR THEN
        pr_log_erro('pkg_petcenter_carga.pr_insert_users', SQLCODE, SQLERRM);

    WHEN OTHERS THEN
        pr_log_erro('pkg_petcenter_carga.pr_insert_users', SQLCODE, SQLERRM);

    END pr_insert_users;

    -- veterinarios
    PROCEDURE pr_insert_veterinarios (
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
        pr_log_erro('pkg_petcenter_carga.pr_insert_veterinarios', SQLCODE, SQLERRM);

    WHEN VALUE_ERROR THEN
        pr_log_erro('pkg_petcenter_carga.pr_insert_veterinarios', SQLCODE, SQLERRM);

    WHEN OTHERS THEN
        pr_log_erro('pkg_petcenter_carga.pr_insert_veterinarios', SQLCODE, SQLERRM);

    END pr_insert_veterinarios;

    -- pets
    PROCEDURE pr_insert_pets (
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
        pr_log_erro('pkg_petcenter_carga.pr_insert_pets', SQLCODE, SQLERRM);

    WHEN VALUE_ERROR THEN
        pr_log_erro('pkg_petcenter_carga.pr_insert_pets', SQLCODE, SQLERRM);

    WHEN OTHERS THEN
        pr_log_erro('pkg_petcenter_carga.pr_insert_pets', SQLCODE, SQLERRM);

    END pr_insert_pets;

    -- pet e veterinario
    PROCEDURE pr_insert_pet_veterinario (
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
        pr_log_erro('pkg_petcenter_carga.pr_insert_pet_veterinario', SQLCODE, SQLERRM);

    WHEN VALUE_ERROR THEN
        pr_log_erro('pkg_petcenter_carga.pr_insert_pet_veterinario', SQLCODE, SQLERRM);

    WHEN OTHERS THEN
        pr_log_erro('pkg_petcenter_carga.pr_insert_pet_veterinario', SQLCODE, SQLERRM);

    END pr_insert_pet_veterinario;

    -- diario entradas
    PROCEDURE pr_insert_diario_entradas (
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
        pr_log_erro('pkg_petcenter_carga.pr_insert_diario_entradas', SQLCODE, SQLERRM);

    WHEN VALUE_ERROR THEN
        pr_log_erro('pkg_petcenter_carga.pr_insert_diario_entradas', SQLCODE, SQLERRM);

    WHEN OTHERS THEN
        pr_log_erro('pkg_petcenter_carga.pr_insert_diario_entradas', SQLCODE, SQLERRM);

    END pr_insert_diario_entradas;

    -- registros
    PROCEDURE pr_insert_registros (
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
        pr_log_erro('pkg_petcenter_carga.pr_insert_registros', SQLCODE, SQLERRM);

    WHEN INVALID_NUMBER THEN
        pr_log_erro('pkg_petcenter_carga.pr_insert_registros', SQLCODE, SQLERRM);

    WHEN OTHERS THEN
        pr_log_erro('pkg_petcenter_carga.pr_insert_registros', SQLCODE, SQLERRM);

    END pr_insert_registros;

    -- comentarios
    PROCEDURE pr_insert_comentarios (
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
        pr_log_erro('pkg_petcenter_carga.pr_insert_comentarios', SQLCODE, SQLERRM);

    WHEN NO_DATA_FOUND THEN
        pr_log_erro('pkg_petcenter_carga.pr_insert_comentarios', SQLCODE, SQLERRM);

    WHEN OTHERS THEN
        pr_log_erro('pkg_petcenter_carga.pr_insert_comentarios', SQLCODE, SQLERRM);

    END pr_insert_comentarios;

    -- insights
    PROCEDURE pr_insert_insights (
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
        pr_log_erro('pkg_petcenter_carga.pr_insert_insights', SQLCODE, SQLERRM);

    WHEN NO_DATA_FOUND THEN
        pr_log_erro('pkg_petcenter_carga.pr_insert_insights', SQLCODE, SQLERRM);

    WHEN OTHERS THEN
        pr_log_erro('pkg_petcenter_carga.pr_insert_insights', SQLCODE, SQLERRM);

    END pr_insert_insights;

    -- solicitacoes
    PROCEDURE pr_insert_solicitacoes (
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
        pr_log_erro('pkg_petcenter_carga.pr_insert_solicitacoes', SQLCODE, SQLERRM);

    WHEN NO_DATA_FOUND THEN
        pr_log_erro('pkg_petcenter_carga.pr_insert_solicitacoes', SQLCODE, SQLERRM);

    WHEN OTHERS THEN
        pr_log_erro('pkg_petcenter_carga.pr_insert_solicitacoes', SQLCODE, SQLERRM);

    END pr_insert_solicitacoes;

    -- (feedback Sprint 3) procedure: pr_insert_alertas
    -- Tabela ALERTAS existia sem procedure de carga parametrizada.
    -- (Sprint 4) empacotada em pkg_petcenter_carga
    PROCEDURE pr_insert_alertas (
    p_pet_id            IN NUMBER,
    p_veterinario_id    IN NUMBER,
    p_tipo              IN VARCHAR2,
    p_titulo            IN VARCHAR2,
    p_descricao         IN VARCHAR2,
    p_data_inicio       IN TIMESTAMP,
    p_frequencia_horas  IN NUMBER,
    p_data_fim          IN TIMESTAMP,
    p_ativo             IN NUMBER
)
IS
BEGIN

    INSERT INTO alertas (
        pet_id,
        veterinario_id,
        tipo,
        titulo,
        descricao,
        data_inicio,
        frequencia_horas,
        data_fim,
        ativo
    )
    VALUES (
        p_pet_id,
        p_veterinario_id,
        p_tipo,
        p_titulo,
        p_descricao,
        p_data_inicio,
        p_frequencia_horas,
        p_data_fim,
        p_ativo
    );

    COMMIT;

EXCEPTION

    WHEN VALUE_ERROR THEN
        pr_log_erro('pkg_petcenter_carga.pr_insert_alertas', SQLCODE, SQLERRM);

    WHEN NO_DATA_FOUND THEN
        pr_log_erro('pkg_petcenter_carga.pr_insert_alertas', SQLCODE, SQLERRM);

    WHEN OTHERS THEN
        pr_log_erro('pkg_petcenter_carga.pr_insert_alertas', SQLCODE, SQLERRM);

    END pr_insert_alertas;

END pkg_petcenter_carga;
/

-- ============================================================
-- 3. CARGA DE DADOS (única)
-- (feedback Sprint 3) pelo menos 5 registros em cada tabela
-- ============================================================

-- USERS (8)
BEGIN

    pkg_petcenter_carga.pr_insert_users(
        'Ana Souza',
        'ana@email.com',
        '123',
        '11999990001',
        'TUTOR'
    );

    pkg_petcenter_carga.pr_insert_users(
        'Carlos Lima',
        'carlos@email.com',
        '123',
        '11999990002',
        'TUTOR'
    );

    pkg_petcenter_carga.pr_insert_users(
        'Dra. Mariana Alves',
        'mariana@email.com',
        '123',
        '11999990003',
        'VETERINARIO'
    );

    pkg_petcenter_carga.pr_insert_users(
        'Dr. Felipe Costa',
        'felipe@email.com',
        '123',
        '11999990004',
        'VETERINARIO'
    );

    pkg_petcenter_carga.pr_insert_users(
        'Beatriz Rocha',
        'beatriz@email.com',
        '123',
        '11999990005',
        'TUTOR'
    );

    pkg_petcenter_carga.pr_insert_users(
        'Dr. Ricardo Mendes',
        'ricardo@email.com',
        '123',
        '11999990006',
        'VETERINARIO'
    );

    pkg_petcenter_carga.pr_insert_users(
        'Dra. Paula Nunes',
        'paula@email.com',
        '123',
        '11999990007',
        'VETERINARIO'
    );

    pkg_petcenter_carga.pr_insert_users(
        'Dr. Bruno Teixeira',
        'bruno@email.com',
        '123',
        '11999990008',
        'VETERINARIO'
    );

END;
/


-- VETERINARIOS (5)
BEGIN

    pkg_petcenter_carga.pr_insert_veterinarios(
        3,
        'CRMV-SP-1001',
        'Clínica Geral',
        'Especialista em pequenos animais'
    );

    pkg_petcenter_carga.pr_insert_veterinarios(
        4,
        'CRMV-SP-1002',
        'Dermatologia',
        'Atendimento especializado em cães e gatos'
    );

    pkg_petcenter_carga.pr_insert_veterinarios(
        6,
        'CRMV-SP-1003',
        'Cardiologia',
        'Acompanhamento de cardiopatias em cães'
    );

    pkg_petcenter_carga.pr_insert_veterinarios(
        7,
        'CRMV-SP-1004',
        'Nutrição',
        'Planos alimentares para pets idosos'
    );

    pkg_petcenter_carga.pr_insert_veterinarios(
        8,
        'CRMV-SP-1005',
        'Ortopedia',
        'Reabilitação e lesões articulares'
    );

END;
/


-- PETS (5)
BEGIN

    pkg_petcenter_carga.pr_insert_pets(
        1,
        'Luna',
        'Cachorro',
        'Shih-tzu',
        TO_DATE('2020-05-10','YYYY-MM-DD'),
        'Pet muito dócil'
    );

    pkg_petcenter_carga.pr_insert_pets(
        1,
        'Mimi',
        'Gato',
        'Siamês',
        TO_DATE('2021-08-15','YYYY-MM-DD'),
        'Gosta de dormir o dia inteiro'
    );

    pkg_petcenter_carga.pr_insert_pets(
        2,
        'Thor',
        'Cachorro',
        'Golden Retriever',
        TO_DATE('2019-03-20','YYYY-MM-DD'),
        'Muito ativo'
    );

    pkg_petcenter_carga.pr_insert_pets(
        2,
        'Rex',
        'Cachorro',
        'Pastor Alemão',
        TO_DATE('2018-11-02','YYYY-MM-DD'),
        'Muito protetor'
    );

    pkg_petcenter_carga.pr_insert_pets(
        5,
        'Mel',
        'Gato',
        'Persa',
        TO_DATE('2022-01-18','YYYY-MM-DD'),
        'Pelagem longa, requer escovação'
    );

END;
/

-- PET_VETERINARIO (5)
BEGIN

    pkg_petcenter_carga.pr_insert_pet_veterinario(
        1,
        1,
        SYSDATE,
        1,
        'Acompanhamento mensal'
    );

    pkg_petcenter_carga.pr_insert_pet_veterinario(
        2,
        2,
        SYSDATE,
        1,
        'Acompanhamento dermatológico'
    );

    pkg_petcenter_carga.pr_insert_pet_veterinario(
        3,
        1,
        SYSDATE,
        1,
        'Controle alimentar'
    );

    pkg_petcenter_carga.pr_insert_pet_veterinario(
        4,
        2,
        SYSDATE,
        1,
        'Acompanhamento de pele e alergia'
    );

    pkg_petcenter_carga.pr_insert_pet_veterinario(
        5,
        3,
        SYSDATE,
        1,
        'Acompanhamento cardiológico'
    );

END;
/


-- DIARIO_ENTRADAS (5)
BEGIN

    pkg_petcenter_carga.pr_insert_diario_entradas(
        1,
        TO_DATE('2026-05-10','YYYY-MM-DD'),
        'Luna comeu menos que o normal',
        'Quieta',
        'COMPLETO'
    );

    pkg_petcenter_carga.pr_insert_diario_entradas(
        2,
        TO_DATE('2026-05-10','YYYY-MM-DD'),
        'Mimi dormiu bastante durante o dia',
        'Calma',
        'COMPLETO'
    );

    pkg_petcenter_carga.pr_insert_diario_entradas(
        3,
        TO_DATE('2026-05-10','YYYY-MM-DD'),
        'Thor brincou muito no parque',
        'Animado',
        'COMPLETO'
    );

    pkg_petcenter_carga.pr_insert_diario_entradas(
        4,
        TO_DATE('2026-05-10','YYYY-MM-DD'),
        'Rex apresentou coceira intensa',
        'Irritado',
        'PARCIAL'
    );

    pkg_petcenter_carga.pr_insert_diario_entradas(
        5,
        TO_DATE('2026-05-10','YYYY-MM-DD'),
        'Mel comeu normalmente e dormiu bem',
        'Calma',
        'COMPLETO'
    );

END;
/


-- REGISTROS (8)

BEGIN

    pkg_petcenter_carga.pr_insert_registros(
        1,
        'ALIMENTACAO',
        'RACAO',
        80,
        'g',
        'Comeu menos que o habitual',
        CURRENT_TIMESTAMP
    );

    pkg_petcenter_carga.pr_insert_registros(
        1,
        'COMPORTAMENTO',
        'QUIETO',
        NULL,
        NULL,
        'Ficou quieta durante a manhã',
        CURRENT_TIMESTAMP
    );

    pkg_petcenter_carga.pr_insert_registros(
        2,
        'ATIVIDADE',
        'SONO',
        10,
        'h',
        'Dormiu bastante',
        CURRENT_TIMESTAMP
    );

    pkg_petcenter_carga.pr_insert_registros(
        3,
        'ATIVIDADE',
        'EXERCICIO',
        2,
        'h',
        'Passeio no parque',
        CURRENT_TIMESTAMP
    );

    pkg_petcenter_carga.pr_insert_registros(
        4,
        'COMPORTAMENTO',
        'COCEIRA',
        8,
        'episodios',
        'Coceira ao longo da tarde',
        CURRENT_TIMESTAMP
    );

    pkg_petcenter_carga.pr_insert_registros(
        5,
        'ALIMENTACAO',
        'RACAO',
        60,
        'g',
        'Porção da manhã',
        CURRENT_TIMESTAMP
    );

    pkg_petcenter_carga.pr_insert_registros(
        1,
        'ALIMENTACAO',
        'RACAO',
        20,
        'g',
        'Complemento da alimentação',
        CURRENT_TIMESTAMP
    );

    pkg_petcenter_carga.pr_insert_registros(
        2,
        'ALIMENTACAO',
        'AGUA',
        500,
        'ml',
        'Consumo de água',
        CURRENT_TIMESTAMP
    );

END;
/


-- COMENTARIOS (5)

BEGIN

    pkg_petcenter_carga.pr_insert_comentarios(
        1,
        3,
        'Monitorar alimentação nos próximos dias'
    );

    pkg_petcenter_carga.pr_insert_comentarios(
        2,
        4,
        'Comportamento aparentemente normal'
    );

    pkg_petcenter_carga.pr_insert_comentarios(
        3,
        3,
        'Excelente nível de atividade'
    );

    pkg_petcenter_carga.pr_insert_comentarios(
        4,
        4,
        'Investigar possível alergia alimentar'
    );

    pkg_petcenter_carga.pr_insert_comentarios(
        5,
        6,
        'Quadro estável no momento'
    );

END;
/


-- INSIGHTS (5)
BEGIN

    pkg_petcenter_carga.pr_insert_insights(
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

    pkg_petcenter_carga.pr_insert_insights(
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

    pkg_petcenter_carga.pr_insert_insights(
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

    pkg_petcenter_carga.pr_insert_insights(
        4,
        'ALERGIA_PELE',
        'Episódios frequentes de coceira',
        'REGRA_DERMATOLOGIA',
        'ALTO',
        TO_DATE('2026-05-10','YYYY-MM-DD'),
        NULL,
        'SISTEMA',
        'ATIVO',
        '{"episodios":8}'
    );

    pkg_petcenter_carga.pr_insert_insights(
        5,
        'ROTINA_ESTAVEL',
        'Alimentação e humor dentro do padrão',
        'REGRA_ROTINA',
        'BAIXO',
        TO_DATE('2026-05-10','YYYY-MM-DD'),
        NULL,
        'SISTEMA',
        'ATIVO',
        '{"status":"estavel"}'
    );

END;
/


-- SOLICITACOES (5)
BEGIN

    pkg_petcenter_carga.pr_insert_solicitacoes(
        1,
        1,
        1,
        'ACEITA',
        'Gostaria de acompanhamento mensal',
        CURRENT_TIMESTAMP
    );

    pkg_petcenter_carga.pr_insert_solicitacoes(
        2,
        1,
        2,
        'PENDENTE',
        'Preciso de ajuda com alergias',
        NULL
    );

    pkg_petcenter_carga.pr_insert_solicitacoes(
        3,
        2,
        1,
        'ACEITA',
        'Consulta preventiva',
        CURRENT_TIMESTAMP
    );

    pkg_petcenter_carga.pr_insert_solicitacoes(
        4,
        2,
        2,
        'ACEITA',
        'Avaliação dermatológica do Rex',
        CURRENT_TIMESTAMP
    );

    pkg_petcenter_carga.pr_insert_solicitacoes(
        5,
        5,
        3,
        'PENDENTE',
        'Check-up cardiológico da Mel',
        NULL
    );

END;
/


-- ALERTAS (5)
BEGIN

    pkg_petcenter_carga.pr_insert_alertas(
        1,
        1,
        'CONSULTA',
        'Retorno da Luna',
        'Consulta de acompanhamento alimentar',
        CURRENT_TIMESTAMP,
        24,
        NULL,
        1
    );

    pkg_petcenter_carga.pr_insert_alertas(
        2,
        2,
        'REMEDIO',
        'Medicação da Mimi',
        'Aplicar medicação tópica',
        CURRENT_TIMESTAMP,
        12,
        NULL,
        1
    );

    pkg_petcenter_carga.pr_insert_alertas(
        3,
        1,
        'ALIMENTACAO',
        'Dieta do Thor',
        'Controlar porção diária',
        CURRENT_TIMESTAMP,
        8,
        NULL,
        1
    );

    pkg_petcenter_carga.pr_insert_alertas(
        4,
        2,
        'EXERCICIO',
        'Passeio do Rex',
        'Caminhada curta para reduzir estresse',
        CURRENT_TIMESTAMP,
        24,
        NULL,
        1
    );

    pkg_petcenter_carga.pr_insert_alertas(
        5,
        3,
        'OUTROS',
        'Escovação da Mel',
        'Escovar pelagem 3 vezes por semana',
        CURRENT_TIMESTAMP,
        48,
        NULL,
        1
    );

END;
/


-- (feedback Sprint 3) conferência: quantidade mínima de 5 registros por tabela
SELECT 'users'            AS tabela, COUNT(*) AS qtd FROM users
UNION ALL SELECT 'veterinarios',     COUNT(*) FROM veterinarios
UNION ALL SELECT 'pets',             COUNT(*) FROM pets
UNION ALL SELECT 'pet_veterinario',  COUNT(*) FROM pet_veterinario
UNION ALL SELECT 'diario_entradas',  COUNT(*) FROM diario_entradas
UNION ALL SELECT 'registros',        COUNT(*) FROM registros
UNION ALL SELECT 'comentarios',      COUNT(*) FROM comentarios
UNION ALL SELECT 'insights',         COUNT(*) FROM insights
UNION ALL SELECT 'solicitacoes',     COUNT(*) FROM solicitacoes
UNION ALL SELECT 'alertas',          COUNT(*) FROM alertas
ORDER BY 1;


-- ============================================================
-- 4. RELATÓRIOS SPRINT 1 E 2
-- ============================================================

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
/


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
/

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
/

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
/


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
/

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
/


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
/



-- ============================================================
-- 5. PACKAGE DE RELATÓRIOS + TESTES (Sprints 3 e 4)
-- ============================================================

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

-- (Sprint 4) package spec: pkg_petcenter_relatorios
-- Agrupa funções de negócio/JSON e as procedures de relatório da Sprint 3.
CREATE OR REPLACE PACKAGE pkg_petcenter_relatorios AS

    FUNCTION fn_pet_json (
        p_pet_id IN NUMBER
    ) RETURN VARCHAR2;

    FUNCTION fn_calcular_idade_pet (
        p_pet_id IN NUMBER
    ) RETURN NUMBER;

    PROCEDURE pr_relatorio_pets_json;

    PROCEDURE pr_relatorio_registros_agrupado;

END pkg_petcenter_relatorios;
/


-- (Sprint 4) package body: pkg_petcenter_relatorios
CREATE OR REPLACE PACKAGE BODY pkg_petcenter_relatorios AS

    FUNCTION fn_pet_json (
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

    END fn_pet_json;

    /* 
       FUNÇÃO 2
       Processo lógico do projeto:
       calcula a idade do pet a partir da sua data de nascimento.
    */
    FUNCTION fn_calcular_idade_pet (
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

    END fn_calcular_idade_pet;

    /* 
       PROCEDURE 1
       Realiza JOIN entre várias tabelas e exibe os dados no formato
       JSON utilizando a Função 1 criada pelo grupo.
     */
    PROCEDURE pr_relatorio_pets_json
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
        pkg_petcenter_carga.pr_log_erro(
            'pkg_petcenter_relatorios.pr_relatorio_pets_json',
            SQLCODE,
            SQLERRM
        );

    WHEN VALUE_ERROR THEN
        DBMS_OUTPUT.PUT_LINE(
            'ERRO pr_relatorio_pets_json: valor inválido.'
        );
        pkg_petcenter_carga.pr_log_erro(
            'pkg_petcenter_relatorios.pr_relatorio_pets_json',
            SQLCODE,
            SQLERRM
        );

    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE(
            'ERRO pr_relatorio_pets_json: ' ||
            SQLCODE || ' - ' || SQLERRM
        );
        pkg_petcenter_carga.pr_log_erro(
            'pkg_petcenter_relatorios.pr_relatorio_pets_json',
            SQLCODE,
            SQLERRM
        );

    END pr_relatorio_pets_json;

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

    PROCEDURE pr_relatorio_registros_agrupado
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
        pkg_petcenter_carga.pr_log_erro(
            'pkg_petcenter_relatorios.pr_relatorio_registros_agrupado',
            SQLCODE,
            SQLERRM
        );

    WHEN VALUE_ERROR THEN
        DBMS_OUTPUT.PUT_LINE(
            'ERRO pr_relatorio_registros_agrupado: valor inválido.'
        );
        pkg_petcenter_carga.pr_log_erro(
            'pkg_petcenter_relatorios.pr_relatorio_registros_agrupado',
            SQLCODE,
            SQLERRM
        );

    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE(
            'ERRO pr_relatorio_registros_agrupado: ' ||
            SQLCODE || ' - ' || SQLERRM
        );
        pkg_petcenter_carga.pr_log_erro(
            'pkg_petcenter_relatorios.pr_relatorio_registros_agrupado',
            SQLCODE,
            SQLERRM
        );

    END pr_relatorio_registros_agrupado;

END pkg_petcenter_relatorios;
/

-- (Sprint 4) teste: função 1 empacotada
SET SERVEROUTPUT ON;

BEGIN

    DBMS_OUTPUT.PUT_LINE('TESTE FUNÇÃO 1');
    DBMS_OUTPUT.PUT_LINE(pkg_petcenter_relatorios.fn_pet_json(1));

    DBMS_OUTPUT.PUT_LINE('TESTE DE EXCEÇÃO - PET INEXISTENTE');
    DBMS_OUTPUT.PUT_LINE(pkg_petcenter_relatorios.fn_pet_json(99999));

END;
/


-- (Sprint 4) teste: função 2 empacotada
SET SERVEROUTPUT ON;

BEGIN

    DBMS_OUTPUT.PUT_LINE('TESTE FUNÇÃO 2');
    DBMS_OUTPUT.PUT_LINE(
        'Idade da Luna: ' || pkg_petcenter_relatorios.fn_calcular_idade_pet(1) || ' anos'
    );

    DBMS_OUTPUT.PUT_LINE('TESTE DE EXCEÇÃO');
    DBMS_OUTPUT.PUT_LINE(
        'Idade do pet inexistente: ' ||
        NVL(TO_CHAR(pkg_petcenter_relatorios.fn_calcular_idade_pet(99999)), 'NULL')
    );

END;
/


-- (Sprint 4) teste: procedure 1 empacotada
SET SERVEROUTPUT ON;

BEGIN

    pkg_petcenter_relatorios.pr_relatorio_pets_json;

END;
/


-- (Sprint 4) teste: procedure 2 empacotada
SET SERVEROUTPUT ON;

BEGIN

    pkg_petcenter_relatorios.pr_relatorio_registros_agrupado;

END;
/


-- ============================================================
-- 6. AUDITORIA: PACKAGE + TRIGGER FINA
-- ============================================================

/* 
   TRIGGER DE AUDITORIA DML

   AFTER INSERT OR UPDATE OR DELETE ON REGISTROS
   (Sprint 4) a lógica vive no package; a trigger só dispara a procedure.
 */

-- (Sprint 4) package spec: pkg_petcenter_auditoria
CREATE OR REPLACE PACKAGE pkg_petcenter_auditoria AS

    PROCEDURE pr_auditar_registros (
        p_tipo_operacao     IN VARCHAR2,
        p_old_id            IN NUMBER DEFAULT NULL,
        p_old_entrada_id    IN NUMBER DEFAULT NULL,
        p_old_tipo          IN VARCHAR2 DEFAULT NULL,
        p_old_subtipo       IN VARCHAR2 DEFAULT NULL,
        p_old_valor         IN NUMBER DEFAULT NULL,
        p_old_unidade       IN VARCHAR2 DEFAULT NULL,
        p_old_nota          IN VARCHAR2 DEFAULT NULL,
        p_old_horario       IN TIMESTAMP DEFAULT NULL,
        p_old_atualizado_em IN TIMESTAMP DEFAULT NULL,
        p_new_id            IN NUMBER DEFAULT NULL,
        p_new_entrada_id    IN NUMBER DEFAULT NULL,
        p_new_tipo          IN VARCHAR2 DEFAULT NULL,
        p_new_subtipo       IN VARCHAR2 DEFAULT NULL,
        p_new_valor         IN NUMBER DEFAULT NULL,
        p_new_unidade       IN VARCHAR2 DEFAULT NULL,
        p_new_nota          IN VARCHAR2 DEFAULT NULL,
        p_new_horario       IN TIMESTAMP DEFAULT NULL,
        p_new_atualizado_em IN TIMESTAMP DEFAULT NULL
    );

END pkg_petcenter_auditoria;
/

-- (Sprint 4) package body: pkg_petcenter_auditoria
CREATE OR REPLACE PACKAGE BODY pkg_petcenter_auditoria AS

    PROCEDURE pr_auditar_registros (
        p_tipo_operacao     IN VARCHAR2,
        p_old_id            IN NUMBER DEFAULT NULL,
        p_old_entrada_id    IN NUMBER DEFAULT NULL,
        p_old_tipo          IN VARCHAR2 DEFAULT NULL,
        p_old_subtipo       IN VARCHAR2 DEFAULT NULL,
        p_old_valor         IN NUMBER DEFAULT NULL,
        p_old_unidade       IN VARCHAR2 DEFAULT NULL,
        p_old_nota          IN VARCHAR2 DEFAULT NULL,
        p_old_horario       IN TIMESTAMP DEFAULT NULL,
        p_old_atualizado_em IN TIMESTAMP DEFAULT NULL,
        p_new_id            IN NUMBER DEFAULT NULL,
        p_new_entrada_id    IN NUMBER DEFAULT NULL,
        p_new_tipo          IN VARCHAR2 DEFAULT NULL,
        p_new_subtipo       IN VARCHAR2 DEFAULT NULL,
        p_new_valor         IN NUMBER DEFAULT NULL,
        p_new_unidade       IN VARCHAR2 DEFAULT NULL,
        p_new_nota          IN VARCHAR2 DEFAULT NULL,
        p_new_horario       IN TIMESTAMP DEFAULT NULL,
        p_new_atualizado_em IN TIMESTAMP DEFAULT NULL
    )
    IS
    BEGIN

        IF p_tipo_operacao = 'INSERT' THEN

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
                new_horario,
                new_atualizado_em -- (feedback Sprint 3) trigger: INSERT registra new_atualizado_em
            )
            VALUES (
                USER,
                'INSERT',
                CURRENT_TIMESTAMP,
                p_new_id,
                p_new_entrada_id,
                p_new_tipo,
                p_new_subtipo,
                p_new_valor,
                p_new_unidade,
                p_new_nota,
                p_new_horario,
                p_new_atualizado_em
            );

        ELSIF p_tipo_operacao = 'UPDATE' THEN

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
                old_atualizado_em, -- (feedback Sprint 3) trigger: UPDATE registra old_atualizado_em
                new_id,
                new_entrada_id,
                new_tipo,
                new_subtipo,
                new_valor,
                new_unidade,
                new_nota,
                new_horario,
                new_atualizado_em -- (feedback Sprint 3) trigger: UPDATE registra new_atualizado_em
            )
            VALUES (
                USER,
                'UPDATE',
                CURRENT_TIMESTAMP,
                p_old_id,
                p_old_entrada_id,
                p_old_tipo,
                p_old_subtipo,
                p_old_valor,
                p_old_unidade,
                p_old_nota,
                p_old_horario,
                p_old_atualizado_em,
                p_new_id,
                p_new_entrada_id,
                p_new_tipo,
                p_new_subtipo,
                p_new_valor,
                p_new_unidade,
                p_new_nota,
                p_new_horario,
                p_new_atualizado_em
            );

        ELSIF p_tipo_operacao = 'DELETE' THEN

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
                old_atualizado_em -- (feedback Sprint 3) trigger: DELETE registra old_atualizado_em
            )
            VALUES (
                USER,
                'DELETE',
                CURRENT_TIMESTAMP,
                p_old_id,
                p_old_entrada_id,
                p_old_tipo,
                p_old_subtipo,
                p_old_valor,
                p_old_unidade,
                p_old_nota,
                p_old_horario,
                p_old_atualizado_em
            );

        END IF;

    EXCEPTION

        WHEN VALUE_ERROR THEN
            pkg_petcenter_carga.pr_log_erro(
                'pkg_petcenter_auditoria.pr_auditar_registros',
                SQLCODE,
                SQLERRM
            );
            RAISE;

        WHEN DUP_VAL_ON_INDEX THEN
            pkg_petcenter_carga.pr_log_erro(
                'pkg_petcenter_auditoria.pr_auditar_registros',
                SQLCODE,
                SQLERRM
            );
            RAISE;

        WHEN OTHERS THEN
            pkg_petcenter_carga.pr_log_erro(
                'pkg_petcenter_auditoria.pr_auditar_registros',
                SQLCODE,
                SQLERRM
            );
            RAISE;

    END pr_auditar_registros;

END pkg_petcenter_auditoria;
/


-- (Sprint 4) trigger: trg_auditoria_registros
-- Trigger fina: não contém regra de negócio; só chama o package.
-- (feedback Sprint 3) continua registrando atualizado_em via a procedure empacotada.
CREATE OR REPLACE TRIGGER trg_auditoria_registros
AFTER INSERT OR UPDATE OR DELETE ON registros
FOR EACH ROW
BEGIN

    IF INSERTING THEN

        pkg_petcenter_auditoria.pr_auditar_registros(
            p_tipo_operacao     => 'INSERT',
            p_new_id            => :NEW.id,
            p_new_entrada_id    => :NEW.entrada_id,
            p_new_tipo          => :NEW.tipo,
            p_new_subtipo       => :NEW.subtipo,
            p_new_valor         => :NEW.valor,
            p_new_unidade       => :NEW.unidade,
            p_new_nota          => :NEW.nota,
            p_new_horario       => :NEW.horario,
            p_new_atualizado_em => :NEW.atualizado_em
        );

    ELSIF UPDATING THEN

        pkg_petcenter_auditoria.pr_auditar_registros(
            p_tipo_operacao     => 'UPDATE',
            p_old_id            => :OLD.id,
            p_old_entrada_id    => :OLD.entrada_id,
            p_old_tipo          => :OLD.tipo,
            p_old_subtipo       => :OLD.subtipo,
            p_old_valor         => :OLD.valor,
            p_old_unidade       => :OLD.unidade,
            p_old_nota          => :OLD.nota,
            p_old_horario       => :OLD.horario,
            p_old_atualizado_em => :OLD.atualizado_em,
            p_new_id            => :NEW.id,
            p_new_entrada_id    => :NEW.entrada_id,
            p_new_tipo          => :NEW.tipo,
            p_new_subtipo       => :NEW.subtipo,
            p_new_valor         => :NEW.valor,
            p_new_unidade       => :NEW.unidade,
            p_new_nota          => :NEW.nota,
            p_new_horario       => :NEW.horario,
            p_new_atualizado_em => :NEW.atualizado_em
        );

    ELSIF DELETING THEN

        pkg_petcenter_auditoria.pr_auditar_registros(
            p_tipo_operacao     => 'DELETE',
            p_old_id            => :OLD.id,
            p_old_entrada_id    => :OLD.entrada_id,
            p_old_tipo          => :OLD.tipo,
            p_old_subtipo       => :OLD.subtipo,
            p_old_valor         => :OLD.valor,
            p_old_unidade       => :OLD.unidade,
            p_old_nota          => :OLD.nota,
            p_old_horario       => :OLD.horario,
            p_old_atualizado_em => :OLD.atualizado_em
        );

    END IF;

END;
/




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

    -- (feedback Sprint 3) teste: trigger UPDATE com atualizado_em
    UPDATE registros
    SET valor = 20,
        nota = 'Registro atualizado para testar UPDATE da trigger',
        atualizado_em = CURRENT_TIMESTAMP
    WHERE id = v_id_registro;

    -- DELETE
    DELETE FROM registros
    WHERE id = v_id_registro;

    COMMIT;

    DBMS_OUTPUT.PUT_LINE(
        'Trigger testada com sucesso: INSERT, UPDATE e DELETE.'
    );

END;
/




   -- EXIBIÇÃO DOS REGISTROS DE AUDITORIA PARA PRINT


BEGIN


    DBMS_OUTPUT.PUT_LINE('AUDITORIA DOS TESTES DA TRIGGER');


    -- (feedback Sprint 3) evidência: print da auditoria com atualizado_em
    FOR r IN (
        SELECT
            id_auditoria,
            usuario_bd,
            tipo_operacao,
            data_operacao,
            old_id,
            old_valor,
            old_atualizado_em,
            new_id,
            new_valor,
            new_atualizado_em
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
            ' | OLD_ATUALIZADO_EM: ' || NVL(TO_CHAR(r.old_atualizado_em, 'YYYY-MM-DD HH24:MI:SS'), 'NULL') ||
            ' | NEW_ID: ' || NVL(TO_CHAR(r.new_id), 'NULL') ||
            ' | NEW_VALOR: ' || NVL(TO_CHAR(r.new_valor), 'NULL') ||
            ' | NEW_ATUALIZADO_EM: ' || NVL(TO_CHAR(r.new_atualizado_em, 'YYYY-MM-DD HH24:MI:SS'), 'NULL')
        );

    END LOOP;

END;
/


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


-- (feedback Sprint 3) consulta: auditoria incluindo atualizado_em
SELECT
    id_auditoria,
    usuario_bd,
    tipo_operacao,
    data_operacao,
    old_tipo,
    old_subtipo,
    old_valor,
    old_atualizado_em,
    new_tipo,
    new_subtipo,
    new_valor,
    new_atualizado_em
FROM auditoria_registros
ORDER BY id_auditoria;


-- ============================================================
-- 7. EVIDÊNCIAS DE EXCEÇÃO
-- ============================================================

-- (feedback Sprint 3) evidência: tratamentos de exceção de cada procedure
-- Cada teste força um erro proposital, registra em logs_erros e imprime o último log.

SET SERVEROUTPUT ON;

DECLARE

    PROCEDURE mostrar_ultimo_log(p_titulo IN VARCHAR2) IS
        v_id            logs_erros.id%TYPE;
        v_procedure     logs_erros.nome_procedure%TYPE;
        v_usuario       logs_erros.usuario_bd%TYPE;
        v_data          logs_erros.data_erro%TYPE;
        v_codigo        logs_erros.codigo_erro%TYPE;
        v_mensagem      logs_erros.mensagem_erro%TYPE;
    BEGIN
        SELECT
            id,
            nome_procedure,
            usuario_bd,
            data_erro,
            codigo_erro,
            mensagem_erro
        INTO
            v_id,
            v_procedure,
            v_usuario,
            v_data,
            v_codigo,
            v_mensagem
        FROM logs_erros
        WHERE id = (SELECT MAX(id) FROM logs_erros);

        DBMS_OUTPUT.PUT_LINE(p_titulo);
        DBMS_OUTPUT.PUT_LINE(
            '  LOG_ID=' || v_id ||
            ' | PROCEDURE=' || v_procedure ||
            ' | USUARIO=' || v_usuario ||
            ' | DATA=' || TO_CHAR(v_data, 'YYYY-MM-DD HH24:MI:SS') ||
            ' | SQLCODE=' || v_codigo ||
            ' | MSG=' || v_mensagem
        );
        DBMS_OUTPUT.PUT_LINE('------------------------------------------------------------');
    END;

BEGIN

    DBMS_OUTPUT.PUT_LINE('===== EVIDENCIAS DE EXCECAO =====');

    -- (feedback Sprint 3) evidência: pr_insert_users / DUP_VAL_ON_INDEX
    pkg_petcenter_carga.pr_insert_users(
        'Ana Souza',
        'ana@email.com',
        '123',
        '11999990001',
        'TUTOR'
    );
    mostrar_ultimo_log('1) pkg_petcenter_carga.pr_insert_users -> DUP_VAL_ON_INDEX (email duplicado)');

    -- (feedback Sprint 3) evidência: pr_insert_users / OTHERS
    pkg_petcenter_carga.pr_insert_users(
        'Usuario Invalido',
        'invalido@email.com',
        '123',
        '11999990099',
        'ADMIN'
    );
    mostrar_ultimo_log('2) pkg_petcenter_carga.pr_insert_users -> OTHERS (tipo_usuario inválido)');

    -- (feedback Sprint 3) evidência: pr_insert_veterinarios / OTHERS
    pkg_petcenter_carga.pr_insert_veterinarios(
        99999,
        'CRMV-XX-0000',
        'Teste',
        'FK inexistente'
    );
    mostrar_ultimo_log('3) pkg_petcenter_carga.pr_insert_veterinarios -> OTHERS (user_id inexistente)');

    -- (feedback Sprint 3) evidência: pr_insert_pets / OTHERS
    pkg_petcenter_carga.pr_insert_pets(
        99999,
        'Pet Fantasma',
        'Cachorro',
        'SRD',
        TO_DATE('2020-01-01','YYYY-MM-DD'),
        'FK inexistente'
    );
    mostrar_ultimo_log('4) pkg_petcenter_carga.pr_insert_pets -> OTHERS (user_id inexistente)');

    -- (feedback Sprint 3) evidência: pr_insert_pet_veterinario / OTHERS
    pkg_petcenter_carga.pr_insert_pet_veterinario(
        99999,
        1,
        SYSDATE,
        1,
        'FK inexistente'
    );
    mostrar_ultimo_log('5) pkg_petcenter_carga.pr_insert_pet_veterinario -> OTHERS (pet_id inexistente)');

    -- (feedback Sprint 3) evidência: pr_insert_diario_entradas / DUP_VAL_ON_INDEX
    pkg_petcenter_carga.pr_insert_diario_entradas(
        1,
        TO_DATE('2026-05-10','YYYY-MM-DD'),
        'Duplicata proposital',
        'Teste',
        'COMPLETO'
    );
    mostrar_ultimo_log('6) pkg_petcenter_carga.pr_insert_diario_entradas -> DUP_VAL_ON_INDEX (pet+data duplicados)');

    -- (feedback Sprint 3) evidência: pr_insert_diario_entradas / OTHERS
    pkg_petcenter_carga.pr_insert_diario_entradas(
        1,
        TO_DATE('2026-05-12','YYYY-MM-DD'),
        'Status inválido',
        'Teste',
        'CANCELADO'
    );
    mostrar_ultimo_log('7) pkg_petcenter_carga.pr_insert_diario_entradas -> OTHERS (status inválido)');

    -- (feedback Sprint 3) evidência: pr_insert_registros / OTHERS
    pkg_petcenter_carga.pr_insert_registros(
        99999,
        'TESTE',
        'TESTE',
        1,
        'un',
        'FK inexistente',
        CURRENT_TIMESTAMP
    );
    mostrar_ultimo_log('8) pkg_petcenter_carga.pr_insert_registros -> OTHERS (entrada_id inexistente)');

    -- (feedback Sprint 3) evidência: pr_insert_comentarios / OTHERS
    pkg_petcenter_carga.pr_insert_comentarios(
        99999,
        1,
        'FK inexistente'
    );
    mostrar_ultimo_log('9) pkg_petcenter_carga.pr_insert_comentarios -> OTHERS (entrada_id inexistente)');

    -- (feedback Sprint 3) evidência: pr_insert_insights / OTHERS
    pkg_petcenter_carga.pr_insert_insights(
        1,
        'TESTE',
        'Nível inválido',
        'TESTE',
        'CRITICO',
        TO_DATE('2026-05-10','YYYY-MM-DD'),
        NULL,
        'TESTE',
        'ATIVO',
        '{"teste":true}'
    );
    mostrar_ultimo_log('10) pkg_petcenter_carga.pr_insert_insights -> OTHERS (nivel_alerta inválido)');

    -- (feedback Sprint 3) evidência: pr_insert_solicitacoes / OTHERS
    pkg_petcenter_carga.pr_insert_solicitacoes(
        1,
        1,
        1,
        'CANCELADA',
        'Status inválido',
        NULL
    );
    mostrar_ultimo_log('11) pkg_petcenter_carga.pr_insert_solicitacoes -> OTHERS (status inválido)');

    -- (feedback Sprint 3) evidência: pr_insert_alertas / OTHERS
    pkg_petcenter_carga.pr_insert_alertas(
        1,
        1,
        'VACINA',
        'Tipo inválido',
        'Teste de exceção',
        CURRENT_TIMESTAMP,
        24,
        NULL,
        1
    );
    mostrar_ultimo_log('12) pkg_petcenter_carga.pr_insert_alertas -> OTHERS (tipo inválido)');

    DBMS_OUTPUT.PUT_LINE('13) pkg_petcenter_relatorios.pr_relatorio_pets_json / pr_relatorio_registros_agrupado');
    DBMS_OUTPUT.PUT_LINE('    NO_DATA_FOUND só ocorre com tabela vazia.');
    DBMS_OUTPUT.PUT_LINE('    Não apagamos os dados da entrega para preservar a carga >= 5.');
    DBMS_OUTPUT.PUT_LINE('===== FIM DAS EVIDENCIAS DE EXCECAO =====');

END;
/


-- ============================================================
-- 8. CONSULTAS FINAIS
-- ============================================================

-- (feedback Sprint 3) consulta: grid de logs_erros para documentação técnica
SELECT
    id,
    nome_procedure,
    usuario_bd,
    TO_CHAR(data_erro, 'YYYY-MM-DD HH24:MI:SS') AS data_erro,
    codigo_erro,
    mensagem_erro
FROM logs_erros
ORDER BY id;


-- (Sprint 4) conferência: packages e trigger empacotada
SELECT
    object_name,
    object_type,
    status
FROM user_objects
WHERE object_name LIKE 'PKG_PETCENTER%'
   OR object_name = 'TRG_AUDITORIA_REGISTROS'
ORDER BY object_type, object_name;



