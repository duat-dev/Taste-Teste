const { createClient } = require('@supabase/supabase-js');
require('dotenv').config({ path: '.env.local' });

// Configurações do Supabase - usando as do app Flutter
const supabaseUrl = 'https://msjzktnkvyycwahpalhb.supabase.co';
const supabaseServiceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1zanprdG5rdnl5Y3dhaHBhbGhiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTQzNDEyNzAsImV4cCI6MjA2OTkxNzI3MH0.Gn9H8darziz1nln79wvNhzKwo6GF0O-3uBJ-IDha9ns';

console.log('🔧 Usando configurações do projeto Flutter:');
console.log('URL:', supabaseUrl);
console.log('Key:', supabaseServiceKey ? '✅ Definida' : '❌ Não definida');

const supabase = createClient(supabaseUrl, supabaseServiceKey, {
    auth: {
        autoRefreshToken: false,
        persistSession: false
    }
});

async function fixUsuariosTable() {
    console.log('🔧 Iniciando correção da tabela usuarios...');
    console.log('URL:', supabaseUrl);
    
    try {
        // 1. Tentar acessar a tabela usuarios diretamente
        console.log('1. Testando acesso à tabela usuarios...');
        
        const { data: usuarios, error: selectError } = await supabase
            .from('usuarios')
            .select('*')
            .limit(1);
            
        if (selectError) {
            console.log('❌ Erro ao acessar tabela usuarios:', selectError.message);
            console.log('Código do erro:', selectError.code);
            
            if (selectError.code === 'PGRST204' || selectError.message.includes('nome')) {
                console.log('🔍 Problema confirmado: coluna "nome" não encontrada');
                
                // 2. Executar SQL para adicionar coluna nome
                console.log('2. Adicionando coluna nome...');
                
                const { data: result, error: sqlError } = await supabase
                    .rpc('exec_sql', {
                        sql: `
                            -- Verificar se coluna nome existe e adicionar se necessário
                            DO $$
                            BEGIN
                                IF NOT EXISTS (
                                    SELECT FROM information_schema.columns 
                                    WHERE table_name = 'usuarios' AND column_name = 'nome'
                                ) THEN
                                    ALTER TABLE usuarios ADD COLUMN nome VARCHAR(255);
                                    RAISE NOTICE 'Coluna nome adicionada com sucesso';
                                ELSE
                                    RAISE NOTICE 'Coluna nome já existe';
                                END IF;
                            END $$;
                        `
                    });
                
                if (sqlError) {
                    console.log('❌ Erro ao executar SQL:', sqlError.message);
                    
                    // Tentar abordagem mais simples
                    console.log('3. Tentando abordagem alternativa...');
                    
                    const { data: altResult, error: altError } = await supabase
                        .rpc('exec_sql', {
                            sql: 'ALTER TABLE usuarios ADD COLUMN IF NOT EXISTS nome VARCHAR(255);'
                        });
                    
                    if (altError) {
                        console.log('❌ Erro na abordagem alternativa:', altError.message);
                    } else {
                        console.log('✅ Coluna nome adicionada (abordagem alternativa)!');
                    }
                } else {
                    console.log('✅ SQL executado com sucesso!');
                }
            }
        } else {
            console.log('✅ Tabela usuarios acessível');
            if (usuarios && usuarios.length > 0) {
                console.log('Exemplo de dados:', usuarios[0]);
            } else {
                console.log('Tabela vazia, mas estrutura OK');
            }
        }

        // 3. Verificar estrutura final
        console.log('4. Verificação final...');
        
        const { data: finalCheck, error: finalError } = await supabase
            .from('usuarios')
            .select('id, email, nome')
            .limit(1);
            
        if (finalError) {
            console.log('❌ Erro na verificação final:', finalError.message);
            return false;
        } else {
            console.log('✅ Verificação final bem-sucedida!');
            console.log('✅ Estrutura da tabela usuarios está correta');
            return true;
        }

    } catch (error) {
        console.error('❌ Erro geral:', error.message);
        return false;
    }
}

// Executar correção
fixUsuariosTable()
    .then((success) => {
        if (success) {
            console.log('🎉 Correção da tabela usuarios concluída com sucesso!');
            console.log('🚀 O app Flutter agora deve funcionar corretamente');
        } else {
            console.log('❌ Falha na correção da tabela usuarios');
        }
        process.exit(success ? 0 : 1);
    })
    .catch((error) => {
        console.error('💥 Falha na correção:', error);
        process.exit(1);
    });