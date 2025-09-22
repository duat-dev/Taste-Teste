const { createClient } = require('@supabase/supabase-js');
const fs = require('fs');
const path = require('path');

// Configurações do Supabase
const supabaseUrl = 'https://msjzktnkvyycwahpalhb.supabase.co';
const supabaseServiceKey = process.env.SUPABASE_SERVICE_ROLE_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1zanprdG5rdnl5Y3dhaHBhbGhiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTQzNDEyNzAsImV4cCI6MjA2OTkxNzI3MH0.Gn9H8darziz1nln79wvNhzKwo6GF0O-3uBJ-IDha9ns';

const supabase = createClient(supabaseUrl, supabaseServiceKey);

async function fixUsuariosTable() {
    console.log('🔧 Iniciando correção da tabela usuarios...');
    
    try {
        // 1. Verificar se a tabela usuarios existe
        console.log('1. Verificando estrutura da tabela usuarios...');
        
        const { data: tables, error: tablesError } = await supabase
            .from('information_schema.tables')
            .select('table_name')
            .eq('table_name', 'usuarios');
            
        if (tablesError) {
            console.log('❌ Erro ao verificar tabelas:', tablesError.message);
        } else {
            console.log('✅ Verificação de tabelas concluída');
        }

        // 2. Tentar criar/corrigir a tabela usuarios
        console.log('2. Executando correção da tabela usuarios...');
        
        const createTableSQL = `
            -- Criar tabela usuarios se não existir
            CREATE TABLE IF NOT EXISTS usuarios (
                id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
                email VARCHAR(255) NOT NULL,
                nome VARCHAR(255),
                telefone VARCHAR(20),
                data_nascimento DATE,
                favoritos UUID[] DEFAULT '{}',
                preferencias JSONB DEFAULT '{}',
                avatar_url TEXT,
                created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
                updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
            );
        `;
        
        const { data: createResult, error: createError } = await supabase.rpc('exec_sql', {
            sql: createTableSQL
        });
        
        if (createError) {
            console.log('❌ Erro ao criar tabela:', createError.message);
            
            // Tentar abordagem alternativa - verificar se coluna nome existe
            console.log('3. Tentando verificar colunas existentes...');
            
            const { data: usuarios, error: selectError } = await supabase
                .from('usuarios')
                .select('*')
                .limit(1);
                
            if (selectError) {
                console.log('❌ Erro ao acessar tabela usuarios:', selectError.message);
                
                if (selectError.message.includes('nome')) {
                    console.log('🔍 Problema confirmado: coluna "nome" não encontrada');
                    
                    // Tentar adicionar coluna nome
                    const addColumnSQL = `ALTER TABLE usuarios ADD COLUMN IF NOT EXISTS nome VARCHAR(255);`;
                    
                    const { data: alterResult, error: alterError } = await supabase.rpc('exec_sql', {
                        sql: addColumnSQL
                    });
                    
                    if (alterError) {
                        console.log('❌ Erro ao adicionar coluna nome:', alterError.message);
                    } else {
                        console.log('✅ Coluna nome adicionada com sucesso!');
                    }
                }
            } else {
                console.log('✅ Tabela usuarios acessível');
                console.log('Dados encontrados:', usuarios);
            }
        } else {
            console.log('✅ Tabela usuarios criada/verificada com sucesso!');
        }

        // 4. Verificar estrutura final
        console.log('4. Verificando estrutura final...');
        
        const { data: finalCheck, error: finalError } = await supabase
            .from('usuarios')
            .select('id, email, nome')
            .limit(1);
            
        if (finalError) {
            console.log('❌ Erro na verificação final:', finalError.message);
        } else {
            console.log('✅ Verificação final bem-sucedida!');
            console.log('Estrutura da tabela usuarios está correta');
        }

    } catch (error) {
        console.error('❌ Erro geral:', error.message);
    }
}

// Executar correção
fixUsuariosTable()
    .then(() => {
        console.log('🎉 Processo de correção concluído!');
        process.exit(0);
    })
    .catch((error) => {
        console.error('💥 Falha na correção:', error);
        process.exit(1);
    });