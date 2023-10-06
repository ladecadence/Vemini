module main

import os
import flag
import net.mbedtls
import net.urllib
import net.http.mime
import io

const (
	status_input            = 10
	status_success          = 20
	status_redirect_temp     = 30
	status_temporary_failure = 40
	status_permanent_failure = 50
)

fn main() {
	// check if we are running as root
	if os.getuid() == 0 || os.geteuid() == 0 {
		eprintln("Can't run as root")
		exit(1)
	}

	// parse flags
    mut fp := flag.new_flag_parser(os.args)
    fp.application(os.args[0])
    fp.version('v0.0.1')
    fp.limit_free_args(0, 0)!
    fp.description('Vemini server')
    fp.skip_executable()
    
	hostname := fp.string('hostname', 0, "localhost", 'hostname')
    root_ca := fp.string("root", 0, "./certs/root.ca", "root CA certificate")
    crt_filename := fp.string('crt', 0, "./certs/crt.pem", 'cert filename')
    key_filename := fp.string('key', 0, "./certs/key.pem", 'key filename')
    content_dir := fp.string('dir', 0, "./gemini", 'content directory')
	validate := fp.bool('validate', 0, false, 'validate SSL certificate')
	port := fp.int("port", 0, 1965, "port number")

    fp.finalize() or {
        eprintln(err)
        println(fp.usage())
        return
    }

	eprintln("Starting vemini server...")
    
	// Create TSL over TCP session.
	ssl_conf := mbedtls.SSLConnectConfig {
        verify: root_ca,
		cert: crt_filename,
		cert_key: key_filename,
		validate: validate,
		in_memory_verification: false
	}

    mut listener := mbedtls.new_ssl_listener("${hostname}:${port}", ssl_conf) or {
        panic("Can't create SSL Listener: ${err}")
    } 

	defer {
        listener.shutdown() or { panic("Problem closing SSL connection: ${err}") }
    }

    serve_gemini(mut listener, content_dir)
}

fn serve_gemini(mut listener mbedtls.SSLListener, content_dir string) {
	for {
		// Accept incoming connection.
		mut conn:= listener.accept() or {
            eprintln("Error with the connection: ${err}")
			continue
		}
		eprintln("Accept connection:")

		go handle_connection(mut conn, content_dir)
	}
}

fn handle_connection(mut conn mbedtls.SSLConn, content_dir string) {
	defer { 
		conn.shutdown() or {
        	panic("Problem terminating the connection")
    	} 
	}

	// get the request
	mut reader := io.new_buffered_reader(reader: conn)
	mut request := reader.read_line() or { 
		send_response_header(mut conn, status_permanent_failure, "Request not valid")
		return
	}
	// Check the size of the request
	if request.len > 1024 {
		send_response_header(mut conn, status_permanent_failure, "Request exceeds maximum permitted length")
		return
	}

	// Parse incoming request URL.
	req_url := urllib.parse(request) or { 
		send_response_header(mut conn, status_permanent_failure, "URL incorrectly formatted")
		return
	}

	// log client addr
	client := conn.peer_addr() or { 
		eprintln("Can't get client address")
		return
	}
	eprintln("${client.str()} : ${req_url}")

	// If the URL ends with a '/' character, assume that the user wants the index.gmi
	// file in the corresponding directory.
	mut req_path := ""
	if req_url.path.ends_with("/") || req_url.path == "" {
		req_path = os.join_path_single(req_url.path, "index.gmi")
	} else {
		req_path = req_url.path
	}
	clean_path := os.real_path(req_path)
	
	// If the content directory is not specified as an absolute path, make it absolute.
	mut root_dir := ""
	if !content_dir.starts_with("/") {
		work_dir := os.getwd()
		// remove ".", "..", etc to prevent directory walk 
		root_dir = os.join_path_single(work_dir, content_dir.replace(".", "")) 
	} else {
		root_dir = content_dir.replace(".", "")
	}

	// Read the contents of the file.
	file_name := os.join_path_single(root_dir, clean_path)
	content := os.read_file(file_name) or { 
		send_response_header(mut conn, status_permanent_failure, "Resource not found")	
		return
	}

	// Determine MIME type.
	mut meta := mime.get_mime_type(os.file_ext(file_name).replace(".", ""))
	if clean_path.ends_with(".gmi") {
		meta = "text/gemini; lang=en; charset=utf-8"
	}

	// send header
	send_response_header(mut conn, status_success, meta)
	// and content
	send_response_content(mut conn, content.bytes())

	eprintln("Close connection.")
}

fn send_response_header(mut conn mbedtls.SSLConn, status_code int, meta string) {
	header := "${status_code} ${meta}\r\n"
	conn.write(header.bytes()) or { 
        panic("Problem sending header: ${err}")
     }
}

fn send_response_content(mut conn mbedtls.SSLConn, content []u8) {
	conn.write(content) or {
        panic("Problem sending data: ${err}")
	}
}
