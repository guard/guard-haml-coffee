require 'guard/compat/test/helper'
require 'guard/haml-coffee'

RSpec.describe Guard::HamlCoffee do
  subject { described_class.new(options) }

  let(:options) { {} }

  let(:runtime) { double(:execjs_runtime) }

  before do
    allow(Guard::Compat::UI).to receive(:info)
    allow(File).to receive(:expand_path) do |*args|
      msg = 'unstubbed call to File.expand_path(%s)'
      fail msg % args.map(&:inspect).join(',')
    end

    allow(IO).to receive(:read) do |*args|
      msg = 'unstubbed call to IO.read(%s)'
      fail msg % args.map(&:inspect).join(',')
    end

    # prepare method expecations
    allow(File).to receive(:expand_path).with('../coffee-script.js', anything).and_return('foo.js')
    allow(IO).to receive(:read).with('foo.js').and_return('foo')

    allow(File).to receive(:expand_path).with('../haml-coffee/hamlcoffee.js', anything).and_return('bar.js')
    allow(IO).to receive(:read).with('bar.js').and_return('bar')

    allow(File).to receive(:expand_path).with('../haml-coffee/hamlcoffee_compiler.js', anything).and_return('baz.js')
    allow(IO).to receive(:read).with('baz.js').and_return('baz')

    allow(ExecJS).to receive(:compile).with('foo;bar;baz').and_return(runtime)
  end

  describe '#initialize' do
    context 'with an unknown option' do
      let(:options) { { foo: :bar } }
      it 'fails' do
        expect { subject }.to raise_error(ArgumentError, 'Unknown option: :foo')
      end
    end

    context 'with a Guard::Plugin watchers option' do
      let(:options) { { watchers: [] } }
      it 'fails' do
        expect { subject }.to_not raise_error
      end
    end

    context 'with a Guard::Plugin group option' do
      let(:options) { { group: [] } }
      it 'fails' do
        expect { subject }.to_not raise_error
      end
    end

    context 'with a Guard::Plugin callbacks option' do
      let(:options) { { callbacks: [] } }
      it 'fails' do
        expect { subject }.to_not raise_error
      end
    end
  end

  describe '#start' do
    context 'with valid config' do
      let(:source) { 'foo' }

      before do
        allow(File).to receive(:expand_path).with('../coffee-script.js', anything).and_return('foo.js')
        allow(IO).to receive(:read).with('foo.js').and_return('foo')

        allow(File).to receive(:expand_path).with('../haml-coffee/hamlcoffee.js', anything).and_return('bar.js')
        allow(IO).to receive(:read).with('bar.js').and_return('bar')

        allow(File).to receive(:expand_path).with('../haml-coffee/hamlcoffee_compiler.js', anything).and_return('baz.js')
        allow(IO).to receive(:read).with('baz.js').and_return('baz')
      end

      it 'compiles' do
        expect(ExecJS).to receive(:compile).with('foo;bar;baz')
        subject.start
      end
    end
  end

  describe '#run_all' do
    context 'with matching files' do
      let(:existing) { %w(foo bar baz) }
      let(:matching) { %w(foo bar) }

      before do
        allow(Dir).to receive(:glob).with(anything).and_return(existing)
        allow(Guard::Compat).to receive(:matching_files).with(subject, existing).and_return(matching)
      end

      it 'compiles' do
        expect(subject).to receive(:process).with(matching)
        subject.run_all
      end
    end
  end

  describe '#run_on_modifications' do
    context 'with modifications' do
      let(:files) { %w(foo bar) }
      it 'compiles' do
        expect(subject).to receive(:process).with(files)
        subject.run_on_modifications(files)
      end
    end
  end

  describe '#run_on_changes' do
    context 'with changes' do
      let(:files) { %w(foo bar) }

      it 'compiles' do
        expect(subject).to receive(:process).with(files)
        subject.run_on_changes(files)
      end

      context "when compiling fails" do
        before do
          allow(Guard::Compat::UI).to receive(:error)
          allow(subject).to receive(:throw).with(:task_has_failed)
          allow(IO).to receive(:read).with('foo').and_return('foo data')
          allow(runtime).to receive(:call).and_raise(Errno::ENOENT, 'foobar')
        end

        it "shows an error" do
          expect(Guard::Compat::UI).to receive(:error)
            .with("Guard Haml Coffee Error: No such file or directory - foobar")
          subject.run_on_changes(files)
        end

        it "throws :task_failed" do
          expect(subject).to receive(:throw).with(:task_has_failed)
          subject.run_on_changes(files)
        end
      end
    end

    context 'when run outside Guard (without start called)' do
      let(:files) { %w(foo.js.hamlc) }
      let(:output) { 'js output' }

      before do
        allow(IO).to receive(:read).with('foo.js.hamlc').and_return('foo')

        allow(runtime).to receive(:call).and_return(output)
      end

      it 'works' do
        subject.run_on_changes(files)
      end
    end
  end
end
