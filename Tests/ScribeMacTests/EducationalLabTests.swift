import XCTest
import Foundation
import CryptoKit
@testable import ScribeMacCore

/// Delegado que impide seguir redirecciones HTTP para pruebas de cadena de redirección.
private final class NoRedirectDelegate: NSObject, URLSessionTaskDelegate, Sendable {
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest: URLRequest,
        completionHandler: @escaping @Sendable (URLRequest?) -> Void
    ) {
        completionHandler(nil)
    }
}

/// Suite de pruebas automatizadas para los 9 escenarios del laboratorio de seguridad educativa.
/// Valida la respuesta del servidor y el comportamiento de ScribeMac frente a cada endpoint /lab/*.
final class EducationalLabTests: XCTestCase {
    nonisolated(unsafe) static var serverProcess: Process?
    static let labPort = 8091
    static let baseURL = "http://127.0.0.1:8091"

    // MARK: - Ciclo de Vida del Servidor

    override class func setUp() {
        super.setUp()

        let serverScript = Bundle.module.url(forResource: "Server/test_server", withExtension: "py", subdirectory: "Fixtures")
            ?? Bundle.module.url(forResource: "test_server", withExtension: "py", subdirectory: "Fixtures/Server")

        guard let scriptURL = serverScript else {
            fatalError("No se encontró test_server.py en los recursos del bundle de pruebas.")
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["python3", scriptURL.path, String(labPort)]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            fatalError("No se pudo iniciar el servidor de laboratorio: \(error)")
        }

        serverProcess = process

        // Esperar a que el servidor esté listo (health check)
        let healthURL = URL(string: "\(baseURL)/health")!
        var ready = false
        for _ in 0..<30 {
            let semaphore = DispatchSemaphore(value: 0)
            nonisolated(unsafe) var response: HTTPURLResponse?
            let task = URLSession.shared.dataTask(with: healthURL) { _, resp, _ in
                response = resp as? HTTPURLResponse
                semaphore.signal()
            }
            task.resume()
            _ = semaphore.wait(timeout: .now() + 1.0)
            if response?.statusCode == 200 {
                ready = true
                break
            }
            Thread.sleep(forTimeInterval: 0.5)
        }

        guard ready else {
            fatalError("El servidor de laboratorio no respondió al health check después de 15 segundos.")
        }
    }

    override class func tearDown() {
        if let process = serverProcess, process.isRunning {
            // Enviar solicitud de shutdown
            let shutdownURL = URL(string: "\(baseURL)/shutdown")!
            let semaphore = DispatchSemaphore(value: 0)
            let task = URLSession.shared.dataTask(with: shutdownURL) { _, _, _ in
                semaphore.signal()
            }
            task.resume()
            _ = semaphore.wait(timeout: .now() + 3.0)

            if process.isRunning {
                process.terminate()
                process.waitUntilExit()
            }
        }
        serverProcess = nil
        super.tearDown()
    }

    // MARK: - Utilidades

    /// Realiza una solicitud HTTP GET síncrona y retorna (data, response).
    private func syncRequest(
        path: String,
        headers: [String: String] = [:],
        followRedirects: Bool = true
    ) -> (Data?, HTTPURLResponse?) {
        let url = URL(string: "\(Self.baseURL)\(path)")!
        var request = URLRequest(url: url)
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        // Configurar sesión sin seguir redirecciones si se necesita
        let config = URLSessionConfiguration.default
        let session: URLSession
        if !followRedirects {
            session = URLSession(configuration: config, delegate: NoRedirectDelegate(), delegateQueue: nil)
        } else {
            session = URLSession(configuration: config)
        }

        let semaphore = DispatchSemaphore(value: 0)
        nonisolated(unsafe) var responseData: Data?
        nonisolated(unsafe) var httpResponse: HTTPURLResponse?

        let task = session.dataTask(with: request) { data, response, _ in
            responseData = data
            httpResponse = response as? HTTPURLResponse
            semaphore.signal()
        }
        task.resume()
        _ = semaphore.wait(timeout: .now() + 15.0)

        return (responseData, httpResponse)
    }

    /// Calcula la firma HMAC-SHA256 de un path.
    private func computeHMAC(path: String) -> String {
        let key = SymmetricKey(data: Data("lab-secret".utf8))
        let sig = HMAC<SHA256>.authenticationCode(for: Data(path.utf8), using: key)
        return Data(sig).map { String(format: "%02x", $0) }.joined()
    }

    // MARK: - 1. PDF Público del Laboratorio

    func testLabPublicPDF() {
        let (data, response) = syncRequest(path: "/lab/public.pdf")

        XCTAssertNotNil(response, "La respuesta no debería ser nula")
        XCTAssertEqual(response?.statusCode, 200, "Debe retornar 200 OK")
        XCTAssertEqual(response?.mimeType, "application/pdf", "MIME debe ser application/pdf")

        // Verificar cabeceras de diagnóstico
        let etag = response?.value(forHTTPHeaderField: "ETag")
        XCTAssertNotNil(etag, "Debe incluir cabecera ETag")
        XCTAssertEqual(etag, "\"lab-pdf-v1\"", "ETag debe ser 'lab-pdf-v1'")

        let server = response?.value(forHTTPHeaderField: "Server")
        XCTAssertTrue(server?.contains("ScribeMac-Lab/1.0") == true, "Server debe contener 'ScribeMac-Lab/1.0', valor actual: \(server ?? "nil")")

        let acceptRanges = response?.value(forHTTPHeaderField: "Accept-Ranges")
        XCTAssertEqual(acceptRanges, "bytes", "Accept-Ranges debe ser 'bytes'")

        // Verificar que el contenido es un PDF válido
        XCTAssertNotNil(data, "El cuerpo de la respuesta no debería ser nulo")
        XCTAssertTrue(data!.starts(with: "%PDF-".data(using: .utf8)!), "El contenido debe comenzar con %PDF-")
    }

    // MARK: - 2. Autenticación Requerida

    func testLabAuthRequired() {
        let (data, response) = syncRequest(path: "/lab/auth-required")

        XCTAssertEqual(response?.statusCode, 401, "Debe retornar 401 Unauthorized")

        let wwwAuth = response?.value(forHTTPHeaderField: "WWW-Authenticate")
        XCTAssertNotNil(wwwAuth, "Debe incluir cabecera WWW-Authenticate")
        XCTAssertTrue(wwwAuth?.contains("Basic") == true, "WWW-Authenticate debe especificar esquema Basic")

        // Verificar JSON de error
        if let data = data {
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            XCTAssertEqual(json?["error"] as? String, "authentication_required")
        }
    }

    // MARK: - 3. URL Firmada (HMAC-SHA256) — Válida

    func testLabSignedURLValid() {
        let path = "/lab/signed-url"
        let sig = computeHMAC(path: path)
        let exp = Int(Date().timeIntervalSince1970) + 30 // 30 segundos en el futuro

        let (data, response) = syncRequest(path: "\(path)?sig=\(sig)&exp=\(exp)")

        XCTAssertEqual(response?.statusCode, 200, "Firma válida y no expirada debe retornar 200")
        XCTAssertNotNil(data, "Debe retornar contenido PDF")
        XCTAssertTrue(data!.starts(with: "%PDF-".data(using: .utf8)!), "El contenido debe ser un PDF")

        let verified = response?.value(forHTTPHeaderField: "X-Signature-Verified")
        XCTAssertEqual(verified, "true", "Debe indicar que la firma fue verificada")
    }

    // MARK: - 4. URL Firmada — Expirada

    func testLabSignedURLExpired() {
        let path = "/lab/signed-url"
        let sig = computeHMAC(path: path)
        let exp = Int(Date().timeIntervalSince1970) - 60 // 60 segundos en el pasado

        let (data, response) = syncRequest(path: "\(path)?sig=\(sig)&exp=\(exp)")

        XCTAssertEqual(response?.statusCode, 410, "URL expirada debe retornar 410 Gone")

        let tokenStatus = response?.value(forHTTPHeaderField: "X-Token-Status")
        XCTAssertEqual(tokenStatus, "expired", "X-Token-Status debe ser 'expired'")

        if let data = data {
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            XCTAssertEqual(json?["error"] as? String, "url_expired")
        }
    }

    // MARK: - 5. URL Firmada — Firma Inválida

    func testLabSignedURLInvalidSig() {
        let exp = Int(Date().timeIntervalSince1970) + 30

        let (_, response) = syncRequest(path: "/lab/signed-url?sig=invalid-signature-value&exp=\(exp)")

        XCTAssertEqual(response?.statusCode, 403, "Firma inválida debe retornar 403 Forbidden")
    }

    // MARK: - 6. Token Expirado (siempre 403)

    func testLabExpiredToken() {
        let (data, response) = syncRequest(path: "/lab/expired-token")

        XCTAssertEqual(response?.statusCode, 403, "Debe retornar 403 Forbidden")

        let tokenStatus = response?.value(forHTTPHeaderField: "X-Token-Status")
        XCTAssertEqual(tokenStatus, "expired", "X-Token-Status debe ser 'expired'")

        if let data = data {
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            XCTAssertEqual(json?["error"] as? String, "token_expired")
            XCTAssertEqual(json?["action_required"] as? String, "refresh_token")
        }
    }

    // MARK: - 7. Rate Limiting (429)

    func testLabRateLimited() {
        // Las primeras 3 solicitudes deben pasar
        for i in 0..<3 {
            let (_, response) = syncRequest(path: "/lab/rate-limited")
            XCTAssertEqual(response?.statusCode, 200, "Solicitud \(i + 1) de 3 debe pasar con 200")
        }

        // La 4ta solicitud debe ser rechazada con 429
        let (data, response) = syncRequest(path: "/lab/rate-limited")
        XCTAssertEqual(response?.statusCode, 429, "La 4ta solicitud debe retornar 429 Too Many Requests")

        let retryAfter = response?.value(forHTTPHeaderField: "Retry-After")
        XCTAssertEqual(retryAfter, "5", "Retry-After debe ser 5 segundos")

        if let data = data {
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            XCTAssertEqual(json?["error"] as? String, "rate_limited")
        }
    }

    // MARK: - 8. Desafío JavaScript (HTML, no PDF)

    func testLabJavaScriptChallenge() {
        let (data, response) = syncRequest(path: "/lab/javascript-challenge")

        XCTAssertEqual(response?.statusCode, 403, "Debe retornar 403 con desafío JavaScript")
        XCTAssertEqual(response?.mimeType, "text/html", "Content-Type debe ser text/html")

        let challengeType = response?.value(forHTTPHeaderField: "X-Challenge-Type")
        XCTAssertEqual(challengeType, "javascript-pow", "X-Challenge-Type debe ser 'javascript-pow'")

        // El contenido no debe ser un PDF
        if let data = data {
            XCTAssertFalse(data.starts(with: "%PDF-".data(using: .utf8)!), "El contenido NO debe ser un PDF")
            let html = String(data: data, encoding: .utf8) ?? ""
            XCTAssertTrue(html.contains("<script>"), "Debe contener etiquetas <script>")
            XCTAssertTrue(html.contains("turnstile"), "Debe referenciar Turnstile")
        }
    }

    // MARK: - 9. Cookie de Sesión — Sin Token

    func testLabSessionCookieWithoutToken() {
        let (data, response) = syncRequest(path: "/lab/session-cookie")

        XCTAssertEqual(response?.statusCode, 200, "Debe retornar 200 (con formulario de login)")
        XCTAssertEqual(response?.mimeType, "text/html", "Sin cookie válida, Content-Type debe ser text/html")

        if let data = data {
            let html = String(data: data, encoding: .utf8) ?? ""
            XCTAssertTrue(html.contains("inicio de sesion") || html.contains("Inicio de Sesion"),
                         "Debe mostrar formulario de login")
            XCTAssertFalse(data.starts(with: "%PDF-".data(using: .utf8)!), "NO debe ser un PDF")
        }
    }

    // MARK: - 10. Documento en Teselas (JSON + PNG)

    func testLabTiledDocument() {
        let (data, response) = syncRequest(path: "/lab/tiled-document")

        XCTAssertEqual(response?.statusCode, 200, "Debe retornar 200 OK")
        XCTAssertEqual(response?.mimeType, "application/json", "Content-Type debe ser application/json")

        guard let data = data else {
            XCTFail("El cuerpo de la respuesta no debería ser nulo")
            return
        }

        // Parsear el manifiesto JSON
        guard let manifest = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tiles = manifest["tiles"] as? [[String: Any]] else {
            XCTFail("No se pudo parsear el manifiesto JSON de teselas")
            return
        }

        XCTAssertEqual(tiles.count, 4, "Debe haber 4 teselas")
        XCTAssertEqual(manifest["document_id"] as? String, "lab-tiled-001")

        // Verificar que las teselas individuales retornan PNG válidos
        for (index, tile) in tiles.enumerated() {
            guard let tileURL = tile["url"] as? String else {
                XCTFail("Tesela \(index) no tiene URL")
                continue
            }
            let (tileData, tileResponse) = syncRequest(path: tileURL)
            XCTAssertEqual(tileResponse?.statusCode, 200, "Tesela \(index) debe retornar 200")
            XCTAssertEqual(tileResponse?.mimeType, "image/png", "Tesela \(index) debe ser PNG")
            XCTAssertNotNil(tileData, "Tesela \(index) debe tener contenido")
            // Verificar firma PNG (primeros 4 bytes: 0x89 P N G)
            if let td = tileData, td.count >= 4 {
                XCTAssertEqual(td[0], 0x89, "Tesela \(index): primer byte PNG debe ser 0x89")
                XCTAssertEqual(td[1], 0x50, "Tesela \(index): segundo byte PNG debe ser 'P'")
            }
        }
    }

    // MARK: - 11. Cadena de Redirecciones

    func testLabRedirectChain() {
        // Verificar que el primer paso devuelve 301 (sin seguir redirecciones)
        let (_, firstResponse) = syncRequest(path: "/lab/redirect-chain", followRedirects: false)
        XCTAssertEqual(firstResponse?.statusCode, 301, "Primer paso debe ser 301 Moved Permanently")

        let firstLocation = firstResponse?.value(forHTTPHeaderField: "Location")
        XCTAssertEqual(firstLocation, "/lab/redirect-chain/step2", "Debe redirigir a step2")

        // Verificar que siguiendo todas las redirecciones se llega al PDF
        let (data, finalResponse) = syncRequest(path: "/lab/redirect-chain", followRedirects: true)
        XCTAssertEqual(finalResponse?.statusCode, 200, "Tras seguir la cadena, debe llegar a 200")
        XCTAssertEqual(finalResponse?.mimeType, "application/pdf", "El destino final debe ser un PDF")

        if let data = data {
            XCTAssertTrue(data.starts(with: "%PDF-".data(using: .utf8)!), "El contenido final debe ser un PDF válido")
        }
    }
}
