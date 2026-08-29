Pod::Spec.new do |s|
  s.name             = 'reczt_rich_share'
  s.version          = '0.0.1'
  s.summary          = 'Native iOS rich-link QuickShare for Reczt.'
  s.description      = <<-DESC
Native iOS UIActivityViewController + LinkPresentation integration used by
Reczt to share tappable rich-link cards without a standalone image attachment.
                       DESC
  s.homepage         = 'https://www.reczt.com'
  s.license          = { :type => 'Proprietary', :text => 'Private application code.' }
  s.author           = { 'Reczt' => 'developer@reczt.invalid' }
  s.source           = { :path => '.' }
  s.source_files     = 'reczt_rich_share/Sources/reczt_rich_share/**/*.swift'
  s.dependency 'Flutter'
  s.platform         = :ios, '13.0'
  s.swift_version    = '5.0'
end
