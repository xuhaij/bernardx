module.exports = {
  id: 'l4-file-management',
  level: 4,
  levelName: 'Multi-step Planning',
  title: 'Organize Files',
  description: "Create folders named 'Documents' and 'Images', then move files into the correct folders based on their extension.",
  route: '/scenarios/l4-file-management',
  initialState: {
    folders: [],
    files: {
      'report.pdf': null,
      'photo.png': null,
      'notes.txt': null,
      'logo.jpg': null,
      'invoice.pdf': null,
      'banner.png': null,
    },
    organized: false,
  },
  endpoints: {
    'POST /api/l4-file-management/create-folder': (store, body) => {
      const folders = store.get('folders');
      const name = (body.name || '').trim();
      if (!name) return { success: false, errors: ['Folder name is required.'] };
      if (folders.includes(name)) return { success: false, errors: [`Folder "${name}" already exists.`] };
      store.set('folders', [...folders, name]);
      return { success: true, message: `Folder "${name}" created.` };
    },
    'POST /api/l4-file-management/move-file': (store, body) => {
      const fileName = body.fileName;
      const targetFolder = body.targetFolder;
      const folders = store.get('folders');
      const files = { ...store.get('files') };
      if (!files.hasOwnProperty(fileName)) return { success: false, errors: [`File "${fileName}" not found.`] };
      if (!folders.includes(targetFolder)) return { success: false, errors: [`Folder "${targetFolder}" does not exist. Create it first.`] };
      files[fileName] = targetFolder;
      store.set('files', files);
      return { success: true, message: `"${fileName}" moved to "${targetFolder}".` };
    },
    'POST /api/l4-file-management/finish': (store) => {
      const files = store.get('files');
      const folders = store.get('folders');
      const hasDocuments = folders.includes('Documents');
      const hasImages = folders.includes('Images');
      if (!hasDocuments || !hasImages) {
        return { success: false, errors: ['You need both "Documents" and "Images" folders.'] };
      }
      const docs = ['report.pdf', 'invoice.pdf', 'notes.txt'];
      const imgs = ['photo.png', 'logo.jpg', 'banner.png'];
      const allDocsInFolder = docs.every((f) => files[f] === 'Documents');
      const allImgsInFolder = imgs.every((f) => files[f] === 'Images');
      if (!allDocsInFolder || !allImgsInFolder) {
        return { success: false, errors: ['Some files are not in the correct folder.'] };
      }
      store.set('organized', true);
      return { success: true, message: 'All files organized correctly!' };
    },
  },
  verify: (store) => {
    const passed = store.get('organized') === true
      && store.get('folders').includes('Documents')
      && store.get('folders').includes('Images');
    return {
      passed,
      message: passed
        ? 'Files organized perfectly!'
        : 'Files have not been fully organized yet.',
      details: {
        folders: store.get('folders'),
        files: store.get('files'),
        organized: store.get('organized'),
      },
    };
  },
  template: 'file-management.html',
};
