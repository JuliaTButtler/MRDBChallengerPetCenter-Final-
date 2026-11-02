// Sprint 4 - Pet Center
// Estrutura MongoDB (banco NoSQL de documentos)

// Decisão de modelagem:
// - 1 database: PetCenter
// - 1 collection: Pets
// - Documento rico/aninhado (tutor, veterinario, diario,
//   registros, comentarios, insights, alertas)
// - NÃO é cópia das tabelas relacionais do Oracle

// Pré-requisito: petcenter_dataset.json na mesma pasta

// 1) Importação dos dados (escolha UMA forma)

//
// Opção A - Compass (usada na demonstração):
//   Connect -> mongodb://localhost:27017
//   Create Database: PetCenter / Collection: Pets
//   Add Data -> Import JSON or CSV file
//   Arquivo: petcenter_dataset.json
//   Formato: JSON array
//
// Opção B - Terminal (mongoimport):
//   mongoimport --db PetCenter --collection Pets --file petcenter_dataset.json --jsonArray
//

// 2) Executar este script no mongosh:
//    mongosh mongodb_petcenter.js
//    ou cole os comandos no mongosh do Compass


use PetCenter

// Índices para consultas eficientes
db.Pets.createIndex({ pet_id: 1 }, { unique: true })
db.Pets.createIndex({ "tutor.email": 1 })

print("Total de pets: " + db.Pets.countDocuments())

// Consulta 1 - listar pets com tutor
print("\n Consulta 1: pets e tutores ")
printjson(
  db.Pets.find(
    {},
    { nome: 1, especie: 1, "tutor.nome": 1, _id: 0 }
  ).toArray()
)

// Consulta 2 - filtro por campo aninhado
print("\n Consulta 2: pets da Ana ")
printjson(
  db.Pets.find(
    { "tutor.email": "ana@email.com" },
    { nome: 1, _id: 0 }
  ).toArray()
)

// Consulta 3 - agregação NoSQL ($unwind + $group)
print("\n Consulta 3: total de registros por pet ")
printjson(
  db.Pets.aggregate([
    { $unwind: "$diario" },
    { $unwind: "$diario.registros" },
    { $group: { _id: "$nome", total_registros: { $sum: 1 } } },
    { $sort: { total_registros: -1 } }
  ]).toArray()
)