from flask import Flask, render_template

app = Flask(__name__)

# Placeholder data for demonstration
papers = [
    {
        'id': 1,
        'title': 'Placeholder Paper',
        'authors': 'A. Author',
        'journal': 'Journal X',
        'date': '2023-01-01',
        'summary': 'This is a placeholder abstract summary with AI insights.',
        'keywords': ['AI', 'placeholder']
    },
    {
        'id': 2,
        'title': 'Another Paper',
        'authors': 'B. Researcher',
        'journal': 'Journal Y',
        'date': '2023-01-02',
        'summary': 'Another sample summary with key results.',
        'keywords': ['ML', 'test']
    }
]

@app.route('/')
def index():
    return render_template('index.html', papers=papers)

@app.route('/personal')
def personal():
    return render_template('personal.html')

@app.route('/paper/<int:paper_id>')
def paper_detail(paper_id):
    paper = next((p for p in papers if p['id'] == paper_id), None)
    return render_template('paper_detail.html', paper=paper)

if __name__ == '__main__':
    app.run(debug=True)
