# Contributing to Agentic PPT

Thanks for your interest in contributing! 🎨

## How to Contribute

### Bug Reports & Feature Requests

Open an [issue](https://github.com/Watermelon4000/agentic-ppt/issues) with:
- Clear title and description
- Steps to reproduce (for bugs)
- Expected vs actual behavior
- Screenshots if applicable

### Pull Requests

1. Fork the repo
2. Create a feature branch: `git checkout -b feature/your-feature`
3. Make your changes
4. Test by opening the HTML files in a browser
5. Commit with a descriptive message
6. Push and open a PR

### Development Setup

No build step needed! Just open the HTML files directly:

```bash
# View the demo presentation
open demo/demo-index.html

# Use the drag editor
open editor/editor.html
```

For the Remotion video pipeline:
```bash
cd remotion-board
npm install
npx remotion preview
```

### Code Style

- **HTML slides**: Self-contained single files, no external dependencies
- **CSS**: Use `clamp()` for all sizes, CSS custom properties for theming
- **JavaScript**: Vanilla JS in editor, React/TypeScript in Remotion components

### What We're Looking For

- 🎨 New visual themes and styles
- ✏️ Editor improvements (tools, shortcuts, UX)
- 🎬 Video pipeline enhancements
- 📖 Documentation and examples
- 🌐 Translations

## Contact

Questions? Reach out at **hello@delicatewatermelon.com**

## License

By contributing, you agree that your contributions will be licensed under the [MIT License](LICENSE).
