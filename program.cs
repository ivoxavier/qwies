using MySql.Data.MySqlClient;
using System;
using System.Data;
using System.IO;
using System.Linq;
using System.Text;
using System.Collections.Generic;
using System.Net;         // NOVO: Necessário para a rede
using System.Net.Mail;    // NOVO: Necessário para o e-mail

class Program
{
    // --- Configuração da Base de Dados e Ficheiros
    private const string ConnectionString = "Server=seu_servidor;Database=sua_base_de_dados;Uid=seu_utilizador;Pwd=sua_senha;";
    private const string OutputDirectory = @"C:\caminho\para\sua\pasta";
    private const string PrimaryKeyColumnName = "id"; 

    // --- NOVO: Configuração do E-mail
    // Detalhes do servidor de e-mail (SMTP)
    private const string SmtpHost = "smtp.seu-servidor.com"; // Ex: smtp.gmail.com, smtp.office365.com
    private const int SmtpPort = 587; // Porta comum para TLS. Use 465 para SSL ou 25 para ligações não seguras.
    private const bool EnableSsl = true; // Use 'true' para ligações seguras (recomendado)

    // Credenciais de autenticação (quem envia o e-mail)
    private const string EmailFrom = "seu_email@exemplo.com";
    private const string EmailPassword = "sua_senha_de_email_ou_app"; // Cuidado com a segurança desta senha

    // Destinatário da notificação de erro
    private const string EmailTo = "destinatario@exemplo.com";


    static void Main(string[] args)
    {
        Directory.CreateDirectory(OutputDirectory);

        foreach (var holdingValue in new[] { 0, 4 })
        {
            Console.WriteLine($"A processar para holding = {holdingValue}...");
            ExtractAndGroupShipments(holdingValue);
        }

        Console.WriteLine("Processo concluído. Pressione qualquer tecla para sair.");
        Console.ReadKey();
    }

    private static void ExtractAndGroupShipments(int holding)
    {
        try // O bloco 'try' agora engloba toda a operação para apanhar qualquer erro
        {
            using (var connection = new MySqlConnection(ConnectionString))
            {
                connection.Open();

                var query = $"SELECT * FROM shipment WHERE holding = {holding} AND (Status IS NULL OR Status != 1)";
                using (var command = new MySqlCommand(query, connection))
                {
                    using (var adapter = new MySqlDataAdapter(command))
                    {
                        var shipmentData = new DataTable();
                        adapter.Fill(shipmentData);

                        if (shipmentData.Rows.Count > 0)
                        {
                            var groupedData = shipmentData.AsEnumerable()
                                              .GroupBy(row => new
                                              {
                                                  Holding = row.Field<object>("holding"),
                                                  Centro = row.Field<object>("centro"),
                                                  Department = row.Field<object>("department"),
                                                  Clicod = row.Field<object>("clicod")
                                              })
                                              .Select(g => new
                                              {
                                                  Key = g.Key,
                                                  Rows = g.CopyToDataTable()
                                              });

                            foreach (var group in groupedData)
                            {
                                var fileName = $"{group.Key.Holding}_{group.Key.Centro}_{group.Key.Department}_{group.Key.Clicod}_shipment.csv";
                                var filePath = Path.Combine(OutputDirectory, fileName);
                                
                                DataTableToCsv(group.Rows, filePath);
                                Console.WriteLine($"Ficheiro gerado: {filePath}");
                                
                                UpdateStatusInDatabase(group.Rows, connection);
                            }
                        }
                        else
                        {
                            Console.WriteLine($"Não foram encontrados dados para processar para holding = {holding}.");
                        }
                    }
                }
            }
        }
        catch (Exception ex)
        {
            Console.WriteLine($"ERRO CRÍTICO ao processar para holding = {holding}: {ex.Message}");
            Console.WriteLine("A tentar enviar notificação por e-mail...");
            
            // NOVO: Chama o método de envio de e-mail em caso de erro
            string subject = $"Erro no Processo de Extração de Shipments (Holding: {holding})";
            string body = $@"
                <p>Ocorreu um erro crítico durante a execução do programa de extração de dados.</p>
                <p><strong>Holding:</strong> {holding}</p>
                <p><strong>Hora do Erro:</strong> {DateTime.Now:dd-MM-yyyy HH:mm:ss}</p>
                <hr>
                <p><strong>Mensagem do Erro:</strong></p>
                <p>{ex.Message}</p>
                <hr>
                <p><strong>Detalhes Técnicos (Stack Trace):</strong></p>
                <pre>{ex.ToString()}</pre>
            ";
            
            SendErrorNotification(subject, body);
        }
    }

    private static void DataTableToCsv(DataTable dt, string filePath)
    {
        var sb = new StringBuilder();
        var columnNames = dt.Columns.Cast<DataColumn>().Select(column => $"\"{column.ColumnName}\"");
        sb.AppendLine(string.Join(",", columnNames));

        foreach (DataRow row in dt.Rows)
        {
            var fields = row.ItemArray.Select(field => $"\"{field.ToString()?.Replace("\"", "\"\"")}\"");
            sb.AppendLine(string.Join(",", fields));
        }

        File.WriteAllText(filePath, sb.ToString(), Encoding.UTF8);
    }

    private static void UpdateStatusInDatabase(DataTable dt, MySqlConnection connection)
    {
        var idsToUpdate = dt.AsEnumerable()
                            .Select(r => r.Field<int>(PrimaryKeyColumnName))
                            .ToList();

        if (idsToUpdate.Any())
        {
            var updateQuery = $"UPDATE shipment SET Status = 1 WHERE {PrimaryKeyColumnName} IN ({string.Join(",", idsToUpdate)})";
            using (var updateCommand = new MySqlCommand(updateQuery, connection))
            {
                int rowsAffected = updateCommand.ExecuteNonQuery();
                Console.WriteLine($"  -> {rowsAffected} registos atualizados para Status = 1.");
            }
        }
    }
    
    // NOVO: Método para enviar a notificação de erro por e-mail
    private static void SendErrorNotification(string subject, string body)
    {
        try
        {
            using (var smtpClient = new SmtpClient(SmtpHost, SmtpPort))
            {
                smtpClient.EnableSsl = EnableSsl;
                smtpClient.Credentials = new NetworkCredential(EmailFrom, EmailPassword);

                using (var mailMessage = new MailMessage())
                {
                    mailMessage.From = new MailAddress(EmailFrom);
                    mailMessage.To.Add(EmailTo);
                    mailMessage.Subject = subject;
                    mailMessage.Body = body;
                    mailMessage.IsBodyHtml = true; // Permite usar HTML no corpo do e-mail

                    smtpClient.Send(mailMessage);
                    Console.WriteLine("Notificação de erro enviada com sucesso.");
                }
            }
        }
        catch (Exception mailEx)
        {
            Console.WriteLine($"FALHA AO ENVIAR O E-MAIL DE ERRO: {mailEx.Message}");
        }
    }
}