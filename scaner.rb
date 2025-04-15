#!/usr/bin/env ruby

VERSION = "1.0.0"
TIMEOUT = 5
THREADS = 4
USER_AGENT = "Mozilla/5.0 (X11; Linux x86_64; rv:68.0) Gecko/20100101 Firefox/68.0"

RED = "\033[0;31m"
GREEN = "\033[0;32m"
YELLOW = "\033[0;33m"
BLUE = "\033[0;34m"
PURPLE = "\033[0;35m"
CYAN = "\033[0;36m"
NC = "\033[0m"

def center_text(text, color = NC)
  cols = `tput cols`.to_i
  padding = [(cols - text.length) / 2, 0].max
  puts "#{' ' * padding}#{color}#{text}#{NC}"
end

def print_header(title, color = BLUE)
  puts "\n#{color}=== #{title} ===#{NC}\n"
end

def print_result(label, value, label_color = CYAN, value_color = GREEN)
  printf "#{label_color}%-20s#{NC} #{value_color}%s#{NC}\n", "#{label}:", value
end

def typewriter_effect(text, color, delay = 0.05)
  print color
  text.each_char do |c|
    print c
    sleep(delay)
  end
  puts NC
end

def show_banner
  system("clear") || system("cls")
  
  center_text("██╗  ██╗     ██████╗  █████╗ ██╗   ██╗", PURPLE)
  center_text("╚██╗██╔╝     ██╔══██╗██╔══██╗╚██╗ ██╔╝", PURPLE)
  center_text(" ╚███╔╝█████╗██████╔╝███████║ ╚████╔╝ ", PURPLE)
  center_text(" ██╔██╗╚════╝██╔══██╗██╔══██║  ╚██╔╝  ", PURPLE)
  center_text("██╔╝ ██╗     ██║  ██║██║  ██║   ██║   ", PURPLE)
  center_text("╚═╝  ╚═╝     ╚═╝  ╚═╝╚═╝  ╚═╝   ╚═╝   ", PURPLE)
  puts
  center_text("X-RAY Network Scanner v#{VERSION}", CYAN)
  center_text("----------------------------------", BLUE)
  center_text("Professional Security Toolset", YELLOW)
  center_text("----------------------------------", BLUE)
  center_text("Author: East Timor Ghost Security", GREEN)
  center_text("GitHub: github.com/EastTimorGhostSecurity", GREEN)
  puts
end

def show_progress(msg, &block)
  spin_chars = ['|', '/', '-', '\\']
  print "#{CYAN}[+] #{msg}...#{NC} "
  
  spinner = Thread.new do
    loop do
      spin_chars.each do |c|
        print "\b#{c}"
        sleep 0.1
      end
    end
  end

  begin
    result = block.call
  rescue => e
    spinner.kill if spinner.alive?
    print "\b#{RED}[✗]#{NC}\n"
    show_status(1, "Error: #{e.message}")
    return nil
  ensure
    spinner.kill if spinner.alive?
  end

  print "\b#{GREEN}[✓]#{NC}\n"
  result
end

def show_status(type, message)
  case type
  when 0 then puts "#{GREEN}[✓] #{message}#{NC}" 
  when 1 then puts "#{RED}[✗] #{message}#{NC}"    
  when 2 then puts "#{YELLOW}[!] #{message}#{NC}" 
  when 3 then puts "#{BLUE}[+] #{message}#{NC}"   
  end
end

def check_root
  if Process.uid == 0
    show_status(1, "This script doesn't require root access!")
    exit 1
  end
end

def install_dependencies
  print_header("SYSTEM INITIALIZATION")
  show_status(3, "Checking system dependencies...")
  
  dependencies = ["nmap", "dig", "curl", "parallel", "jq"]
  missing = dependencies.reject { |dep| system("command -v #{dep} > /dev/null 2>&1") }
  
  unless missing.empty?
    show_status(2, "Required packages: #{missing.join(', ')}")
    
    show_progress("Updating package list") do
      system("pkg update -y > /dev/null 2>&1") || raise("Failed to update packages")
    end
    
    missing.each do |pkg|
      show_progress("Installing #{pkg}") do
        system("pkg install -y #{pkg} > /dev/null 2>&1") || raise("Failed to install #{pkg}")
      end
    end
  end
  
  show_status(0, "All dependencies installed")
  sleep 1
end

def prepare_environment
  show_banner
  print_header("TARGET SETUP")
  
  loop do
    print "#{CYAN}[?] Enter target domain: #{NC}"
    domain = gets.chomp
    
    if domain =~ /^([a-zA-Z0-9-]+\.)+[a-zA-Z]{2,}$/
      show_status(3, "Resolving IP address...")
      
      ip = `dig +short A #{domain} | grep -Eo '([0-9]{1,3}\\.){3}[0-9]{1,3}' | head -1`.chomp
      begin
        if ip.empty?
          ip = JSON.parse(`curl -s "https://dns.google/resolve?name=#{domain}&type=A"`)["Answer"].first["data"] 
        end
      rescue
        ip = `host #{domain} | grep -oE '([0-9]{1,3}\\.){3}[0-9]{1,3}' | head -1`.chomp
      end
      
      @domain = domain
      @ip = ip unless ip.to_s.empty?
      break
    else
      show_status(1, "Invalid domain format!")
    end
  end
  
  @output_dir = "scan_results_#{@domain}_#{Time.now.strftime('%Y%m%d_%H%M%S')}"
  begin
    Dir.mkdir(@output_dir)
  rescue => e
    show_status(1, "Failed to create output directory: #{e.message}")
    exit(1)
  end
  
  print_result("Target Domain", @domain, CYAN, PURPLE)
  if @ip
    print_result("IP Address", @ip, CYAN, GREEN)
    File.write("#{@output_dir}/ip_address.txt", @ip)
  else
    print_result("IP Address", "Not found (will attempt during scan)", CYAN, YELLOW)
  end
  print_result("Output Directory", @output_dir, CYAN, PURPLE)
  sleep 1
end

def dns_scan
  show_banner
  print_header("DNS SCAN REPORT")
  
  show_status(3, "Starting DNS reconnaissance...")
  
  unless @ip
    show_status(2, "Reattempting IP resolution...")
    @ip = `dig +short A #{@domain} | grep -Eo '([0-9]{1,3}\\.){3}[0-9]{1,3}' | head -1`.chomp
    File.write("#{@output_dir}/ip_address.txt", @ip) if @ip && !@ip.empty?
  end
  
  if @ip && !@ip.empty?
    print_result("Resolved IP", @ip, CYAN, GREEN)
  else
    show_status(1, "Failed to resolve IP address!")
  end
  
  puts "\n#{CYAN}» DNS Records:#{NC}"
  
  # A Records
  print_header("A RECORDS")
  `dig +short A #{@domain}`.each_line do |record|
    print_result("A Record", record.chomp, BLUE)
    File.write("#{@output_dir}/dns_a.txt", record, mode: 'a')
  end
  
  # MX Records
  print_header("MX RECORDS")
  `dig +short MX #{@domain}`.each_line do |record|
    print_result("MX Record", record.chomp, BLUE)
    File.write("#{@output_dir}/dns_mx.txt", record, mode: 'a')
  end
  
  # TXT Records
  print_header("TXT RECORDS")
  `dig +short TXT #{@domain}`.each_line do |record|
    print_result("TXT Record", record.chomp, BLUE)
    File.write("#{@output_dir}/dns_txt.txt", record, mode: 'a')
  end
  
  # NS Records
  print_header("NS RECORDS")
  `dig +short NS #{@domain}`.each_line do |record|
    print_result("NS Record", record.chomp, BLUE)
    File.write("#{@output_dir}/dns_ns.txt", record, mode: 'a')
  end
  
  show_status(0, "DNS scan completed")
  puts "\n#{YELLOW}Press Enter to continue...#{NC}"
  gets
end

def port_scan
  show_banner
  print_header("PORT SCAN REPORT")
  
  unless @ip && !@ip.empty?
    show_status(1, "IP address not available!")
    puts "#{YELLOW}Perform DNS scan first.#{NC}"
    puts "\n#{YELLOW}Press Enter to return...#{NC}"
    gets
    return
  end

  begin
    show_status(3, "Starting port scanning on #{PURPLE}#{@ip}#{NC}")

    # Fast Top Ports Scan
    print_header("TOP 1000 PORTS SCAN")
    show_progress("Scanning top ports") do
      output = `nmap --unprivileged -T4 -Pn -sT --top-ports 1000 --open -oG - #{@ip} 2>&1`
      
      unless $?.success?
        raise "Nmap failed with exit code #{$?.exitstatus}: #{output.lines.first.chomp}"
      end

      found_ports = false
      output.each_line do |line|
        if line =~ /(\d+)\/open/
          print_result("Open Port", "#{$1}/open", CYAN)
          File.write("#{@output_dir}/nmap_top_ports.txt", line, mode: 'a')
          found_ports = true
        end
      end
      
      show_status(2, "No open ports found") unless found_ports
    end

    # Deep Comprehensive Scan
    print_header("DEEP COMPREHENSIVE SCAN")
    show_progress("Running deep scan (5-15 minutes)") do
      output = `nmap -p- -sV -O -T4 --script vulners #{@ip} 2>&1`
      
      unless $?.success?
        raise "Deep scan failed with exit code #{$?.exitstatus}: #{output.lines.first.chomp}"
      end

      found_info = false
      output.each_line do |line|
        case line
        when /(\d+)\/open/
          print_result("Open Port", $1, BLUE)
          found_info = true
        when /Running: (.+)/
          print_result("OS Detection", $1, PURPLE)
          found_info = true
        when /Service: (.+)/
          print_result("Service Info", $1, GREEN)
          found_info = true
        end
        File.write("#{@output_dir}/nmap_deep_scan.txt", line, mode: 'a')
      end
      
      show_status(2, "No additional info found") unless found_info
    end

    # Vulnerability Scan
    print_header("VULNERABILITY SCAN")
    show_progress("Checking common vulnerabilities") do
      output = `nmap --script vuln #{@ip} 2>&1`
      
      unless $?.success?
        raise "Vuln scan failed with exit code #{$?.exitstatus}: #{output.lines.first.chomp}"
      end

      found_vulns = false
      output.each_line do |line|
        if line =~ /(CVE-\d+-\d+)|(VULNERABLE)/
          print_result("Vulnerability", line.chomp, RED)
          File.write("#{@output_dir}/vulnerabilities.txt", line, mode: 'a')
          found_vulns = true
        end
      end
      
      show_status(0, "No vulnerabilities found") unless found_vulns
    end

    show_status(0, "Port scanning completed")
  rescue => e
    show_status(1, "Port scan failed: #{e.message}")
  ensure
    puts "\n#{YELLOW}Press Enter to continue...#{NC}"
    gets
  end
end

def subdomain_scan
  show_banner
  print_header("SUBDOMAIN ENUMERATION")
  
  wordlist = "subdomains.txt"
  
  unless File.exist?(wordlist)
    show_status(2, "Creating default wordlist...")
    File.write(wordlist, <<~EOL)
      www
      mail
      ftp
      admin
      api
      dev
      test
      staging
      webmail
      portal
    EOL
  end
  
  show_status(3, "Starting subdomain enumeration with #{PURPLE}#{wordlist}#{NC}")
  
  print_header("DISCOVERED SUBDOMAINS")
  total = File.readlines(wordlist).size
  count = 0
  
  begin
    File.foreach(wordlist) do |sub|
      sub.chomp!
      count += 1
      print "\r#{BLUE}Progress: #{YELLOW}#{count}/#{total}#{NC}"
      
      ip = `dig +short A #{sub}.#{@domain} 2>/dev/null | grep -Eo '([0-9]{1,3}\\.){3}[0-9]{1,3}'`.chomp
      unless ip.empty?
        print_result("#{sub}.#{@domain}", ip, BLUE, GREEN)
        File.write("#{@output_dir}/subdomains.csv", "#{sub}.#{@domain},#{ip}\n", mode: 'a')
      end
    end
    puts
    
    show_status(0, "Subdomain scan completed")
  rescue => e
    show_status(1, "Subdomain scan failed: #{e.message}")
  ensure
    puts "\n#{YELLOW}Press Enter to continue...#{NC}"
    gets
  end
end

def full_scan
  show_banner
  print_header("COMPREHENSIVE SCAN")
  
  begin
    show_status(3, "Starting full reconnaissance on #{PURPLE}#{@domain}#{NC}")
    
    dns_scan
    port_scan
    subdomain_scan
    
    show_status(0, "All scans completed!")
  rescue => e
    show_status(1, "Comprehensive scan failed: #{e.message}")
  ensure
    puts "\n#{GREEN}Results saved to: #{PURPLE}#{@output_dir}#{NC}"
    puts "\n#{YELLOW}Press Enter to return to menu...#{NC}"
    gets
  end
end

def show_menu
  loop do
    show_banner
    print_header("MAIN MENU")
    
    print_result("Current Target", @domain, CYAN, PURPLE)
    print_result("IP Address", @ip || "Not resolved", CYAN, @ip ? GREEN : YELLOW)
    print_result("Output Directory", @output_dir, CYAN, PURPLE)
    
    puts "\n#{BLUE}Scan Options:#{NC}"
    puts "#{GREEN}[1]#{NC} DNS Scan"
    puts "#{GREEN}[2]#{NC} Port Scan"
    puts "#{GREEN}[3]#{NC} Subdomain Scan"
    puts "#{GREEN}[4]#{NC} Full Comprehensive Scan"
    puts "#{GREEN}[5]#{NC} Change Target"
    puts "#{RED}[6]#{NC} Exit"
    
    print "\n#{CYAN}» Select option [1-6]: #{NC}"
    choice = gets.chomp.to_i
    
    case choice
    when 1 then dns_scan
    when 2 then port_scan
    when 3 then subdomain_scan
    when 4 then full_scan
    when 5 then prepare_environment
    when 6 then break
    else
      show_status(1, "Invalid selection!")
      sleep 1
    end
  end
end

def show_exit_message
  show_banner
  print "\n#{CYAN}"
  "Thank you for using X-RAY Scanner!".each_char do |c|
    print c
    sleep 0.05
  end
  puts NC
  sleep 1
end

def main
  begin
    check_root
    show_banner
    install_dependencies
    prepare_environment
    show_menu
    show_exit_message
  rescue Interrupt
    puts "\n#{RED}[!] Script interrupted by user#{NC}"
    exit 1
  rescue => e
    puts "\n#{RED}[!] Fatal error: #{e.message}#{NC}"
    exit 1
  end
end

main
