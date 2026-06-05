project('singularity-greeter', ['vala', 'c'],
  version: '0.1.0',
  meson_version: '>= 0.59.0'
)

i18n = import('i18n')
add_project_arguments('-DGETTEXT_PACKAGE="singularity-greeter"', language: 'c')
add_project_arguments('-D_GNU_SOURCE', language: 'c')
add_project_arguments('--pkg=posix', language: 'vala')
subdir('po')

gnome = import('gnome')

gtk_dep        = dependency('gtk4')
gio_unix_dep   = dependency('gio-unix-2.0')
gee_dep        = dependency('gee-0.8')
json_dep       = dependency('json-glib-1.0')
layershell_dep = dependency('gtk4-layer-shell-0')

libsingularity_dep = dependency('singularity-1.0',
  fallback: ['libsingularity', 'libsingularity_dep']
)

if not meson.is_subproject() and libsingularity_dep.type_name() == 'internal'
  libsingularity_vapi_dir = join_paths(meson.project_build_root(), 'subprojects', 'libsingularity')
  add_project_arguments(['--vapidir=' + libsingularity_vapi_dir], language: 'vala')
endif

resources = gnome.compile_resources(
  'singularity-greeter-resources',
  'resources/dev.sinty.greeter.gresource.xml',
  source_dir: join_paths(meson.current_source_dir(), 'resources')
)

sources = files(
  'src/main.vala',
  'src/app.vala',
  'src/greeter_window.vala',
  'src/user_card.vala',
  'src/greeter_topbar.vala',
  'src/power_menu_dialog.vala',
  'src/greetd_client.vala',
)

executable('singularity-greeter',
  sources + [resources],
  dependencies: [gtk_dep, gio_unix_dep, gee_dep, json_dep, layershell_dep, libsingularity_dep],
  install: true
)

install_data('data/dev.sinty.greeter.gschema.xml',
  install_dir: get_option('datadir') / 'glib-2.0' / 'schemas'
)
